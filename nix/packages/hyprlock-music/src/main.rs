//! Music widget for Hyprlock. Reads the active MPRIS player directly over D-Bus.
//!
//! `--watch` keeps the text and art cache files current. It wakes only on D-Bus
//! signals: a player appearing or vanishing, or an MPRIS property changing.
//! Position, length and progress bar are read live by hyprlock via the CLI.

use std::collections::hash_map::DefaultHasher;
use std::env;
use std::fs;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, SystemTime};

use dbus::arg::PropMap;
use dbus::blocking::Connection;
use dbus::message::MatchRule;
use mpris::{PlaybackStatus, Player, PlayerFinder};

const MPRIS_PREFIX: &str = "org.mpris.MediaPlayer2.";
/// Preferred players by short MPRIS name, most preferred first.
const PREFERRED_PLAYERS: [&str; 7] = ["spotify", "mpv", "vlc", "firefox", "chromium", "brave", "chrome"];
const SQUARE_SIZE: u32 = 512;
/// Progress resolution: 16 cells x 512 sub-steps.
const BAR_STEPS: u64 = 8192;
/// Progress bar image in px. Drawn at 2x so it stays sharp; the Nix config shows
/// it at half this size (176px wide on the 1920 reference, the old text bar's width).
const BAR_WIDTH: u64 = 352;
const BAR_HEIGHT: u32 = 24;
/// Vertical band of the bar inside the image: y0..y1, with a fully rounded end.
const BAR_TOP: u32 = 6;
const BAR_BOTTOM: u32 = 18;
const BAR_RADIUS: u32 = 6;

struct Env {
    font: String,
    foreground: String,
    cache_dir: PathBuf,
    art_dir: PathBuf,
    fallback_art: Option<PathBuf>,
}

impl Env {
    fn from_env() -> Self {
        let home = env::var("HOME").unwrap_or_default();
        let xdg = env::var("XDG_CACHE_HOME").unwrap_or_else(|_| format!("{home}/.cache"));
        let fallback = env::var("HYPRLOCK_MUSIC_FALLBACK_ART").unwrap_or_default();
        Self {
            font: env::var("HYPRLOCK_MUSIC_FONT").unwrap_or_else(|_| "sans".into()),
            foreground: env::var("HYPRLOCK_MUSIC_FOREGROUND").unwrap_or_else(|_| "ffffff".into()),
            cache_dir: env::var("HYPRLOCK_MUSIC_CACHE_DIR")
                .map(PathBuf::from)
                .unwrap_or_else(|_| PathBuf::from(format!("{xdg}/hyprlock-music"))),
            art_dir: PathBuf::from(format!("{xdg}/hyprlock-art")),
            fallback_art: (!fallback.is_empty()).then(|| PathBuf::from(fallback)),
        }
    }
}

// ---------------------------------------------------------------------------
// Player selection
// ---------------------------------------------------------------------------

/// `org.mpris.MediaPlayer2.spotify.instance1` -> `spotify`
fn short_name(player: &Player) -> &str {
    player
        .bus_name()
        .trim_start_matches(MPRIS_PREFIX)
        .split('.')
        .next()
        .unwrap_or_default()
}

/// Only playing or paused players count; idle ones (e.g. Chromium with a stale
/// art URL) are ignored. Preferred player first, otherwise the first one.
fn select_player(players: Vec<Player>) -> Option<Player> {
    let rank = |p: &Player| {
        PREFERRED_PLAYERS
            .iter()
            .position(|name| *name == short_name(p))
            .unwrap_or(usize::MAX)
    };
    players
        .into_iter()
        .filter(|p| matches!(p.get_playback_status(), Ok(PlaybackStatus::Playing | PlaybackStatus::Paused)))
        .min_by_key(rank)
}

fn current_player(finder: &PlayerFinder) -> Option<Player> {
    select_player(finder.find_all().unwrap_or_default())
}

fn status_of(player: Option<&Player>) -> Option<PlaybackStatus> {
    player.and_then(|p| p.get_playback_status().ok())
}

fn metadata_of(player: Option<&Player>) -> Option<mpris::Metadata> {
    player.and_then(|p| p.get_metadata().ok())
}

// ---------------------------------------------------------------------------
// Text fields
// ---------------------------------------------------------------------------

/// Truncate to `max` characters, adding an ellipsis when cut.
fn trim(text: &str, max: usize) -> String {
    if text.chars().count() <= max {
        text.to_string()
    } else {
        format!("{}…", text.chars().take(max).collect::<String>())
    }
}

fn mmss(duration: Duration) -> String {
    let secs = duration.as_secs();
    format!("{}:{:02}", secs / 60, secs % 60)
}

fn status_icon(status: Option<PlaybackStatus>) -> &'static str {
    match status {
        Some(PlaybackStatus::Playing) => "󰏤",
        Some(PlaybackStatus::Paused) => "󰐊",
        _ => "󰓛",
    }
}

fn player_display(player: Option<&Player>) -> String {
    let Some(player) = player else {
        return "Unknown".into();
    };
    let icon = match short_name(player) {
        "spotify" => "󰓇  Spotify",
        "firefox" => "󰈹  Firefox",
        "chromium" => "󰊯  Chromium",
        "brave" => "󰞀  Brave",
        "chrome" => "󰊯  Chrome",
        "mpv" => "󰕼  mpv",
        "vlc" => "󰕼  VLC",
        _ => return player.identity().to_string(),
    };
    icon.to_string()
}

/// Rendered width in pixels of `text` in the lock-screen font, as hyprlock
/// draws it. Hyprlock ignores `<span size>`, so the text itself must fit.
fn text_width(env: &Env, text: &str, bold: bool, size: u32) -> u32 {
    let font = if bold { format!("{} Bold", env.font) } else { env.font.clone() };
    let escaped = text.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;");
    Command::new("magick")
        .args(["-background", "none", "-font", &font, "-pointsize", &size.to_string()])
        .arg(format!("pango:{escaped}"))
        .args(["-format", "%w", "info:"])
        .stderr(Stdio::null())
        .output()
        .ok()
        .and_then(|out| String::from_utf8(out.stdout).ok())
        .and_then(|s| s.trim().parse::<u32>().ok())
        .unwrap_or(0)
}

/// Shorten text, one character at a time, until it fits the 240px text column
/// left of the album art. Hyprlock cannot scale a label at runtime, so an
/// over-wide title is cut and given an ellipsis. Width 0 (measure failed) leaves
/// the text unchanged.
fn fit_text(env: &Env, text: &str, bold: bool, size: u32) -> String {
    const MAX_WIDTH: u32 = 240;
    let escape = |s: &str| s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;");
    let mut body: Vec<char> = text.trim_end_matches('…').chars().collect();
    let mut shown = text.to_string();
    while text_width(env, &escape(&shown), bold, size) > MAX_WIDTH && !body.is_empty() {
        body.pop();
        shown = format!("{}…", body.iter().collect::<String>());
    }
    escape(&shown)
}

fn title_markup(env: &Env, player: Option<&Player>) -> String {
    let title = metadata_of(player)
        .and_then(|m| m.title().map(str::to_owned))
        .filter(|t| !t.is_empty())
        .unwrap_or_else(|| "Nothing Playing".into());
    fit_text(env, &trim(&title, 29), true, 16)
}

fn artist_markup(env: &Env, player: Option<&Player>) -> String {
    let artist = metadata_of(player)
        .and_then(|m| m.artists().map(|a| a.join(", ")))
        .unwrap_or_default();
    fit_text(env, &trim(&artist, 26), false, 12)
}

// ---------------------------------------------------------------------------
// Live fields (position, length, progress)
// ---------------------------------------------------------------------------

fn position_of(player: Option<&Player>) -> Duration {
    player
        .and_then(|p| p.get_position().ok())
        .unwrap_or_default()
}

fn length_of(player: Option<&Player>) -> Duration {
    metadata_of(player).and_then(|m| m.length()).unwrap_or_default()
}

fn progress_percent(player: Option<&Player>) -> u64 {
    let length = length_of(player).as_micros() as u64;
    if length == 0 {
        return 0;
    }
    position_of(player).as_micros() as u64 * 100 / length
}

/// Draw the Apple-style bar as a PNG for hyprlock's image widget: a track in the
/// remaining color, with the played part drawn over it. Rewritten only when the
/// step changes. Returns the PNG path.
fn progress_image(env: &Env, player: Option<&Player>) -> Option<PathBuf> {
    let stopped = matches!(status_of(player), None | Some(PlaybackStatus::Stopped));
    // Treat 95%+ as 100% so players switching tracks early still look complete.
    let mut percent = progress_percent(player);
    if percent >= 95 {
        percent = 100;
    }
    let units = if stopped { 0 } else { (percent * BAR_STEPS / 100).min(BAR_STEPS) };

    let output = env.cache_dir.join("progress.png");
    let stamp = env.cache_dir.join("progress.steps");
    let step = units.to_string();
    if output.exists() && fs::read_to_string(&stamp).ok().as_deref() == Some(step.as_str()) {
        return Some(output);
    }

    let played = format!("#{}99", env.foreground);
    let remaining = format!("#{}30", env.foreground);
    let filled = BAR_WIDTH * units / BAR_STEPS;
    let track = format!("roundrectangle 0,{BAR_TOP} {},{BAR_BOTTOM} {BAR_RADIUS},{BAR_RADIUS}", BAR_WIDTH - 1);
    let tmp = env.cache_dir.join("progress.tmp.png");
    let mut cmd = Command::new("magick");
    cmd.args(["-size", &format!("{BAR_WIDTH}x{BAR_HEIGHT}"), "xc:none"])
        .args(["-fill", &remaining, "-draw", &track]);
    if filled > 0 {
        let fill = format!("roundrectangle 0,{BAR_TOP} {},{BAR_BOTTOM} {BAR_RADIUS},{BAR_RADIUS}", filled - 1);
        cmd.args(["-fill", &played, "-draw", &fill]);
    }
    let ok = cmd
        .arg(&tmp)
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    if !ok {
        return None;
    }
    fs::rename(&tmp, &output).ok()?;
    let _ = write_atomic(&stamp, &step);
    Some(output)
}

// ---------------------------------------------------------------------------
// Album art
// ---------------------------------------------------------------------------

fn is_newer(file: &Path, than: &Path) -> bool {
    let mtime = |p: &Path| fs::metadata(p).and_then(|m| m.modified()).unwrap_or(SystemTime::UNIX_EPOCH);
    fs::metadata(file).map(|m| m.len() > 0).unwrap_or(false) && mtime(file) >= mtime(than)
}

/// Download a remote art URL into the art cache. Skips files already present.
fn download_art(env: &Env, url: &str) -> Option<PathBuf> {
    let mut hasher = DefaultHasher::new();
    url.hash(&mut hasher);
    let output = env.art_dir.join(format!("{:016x}.img", hasher.finish()));
    let present = fs::metadata(&output).map(|m| m.len() > 0).unwrap_or(false);
    if !present {
        let ok = Command::new("curl")
            .args(["-fsSL", "--max-time", "5", "-o"])
            .arg(&output)
            .arg(url)
            .status()
            .map(|s| s.success())
            .unwrap_or(false);
        if !ok {
            let _ = fs::remove_file(&output);
            return None;
        }
    }
    Some(output)
}

/// Square-crop an image into the art cache. Falls back to the original file.
fn square_cover(env: &Env, input: &Path) -> PathBuf {
    let stem = input.file_stem().unwrap_or_default().to_string_lossy();
    let output = env.art_dir.join(format!("{stem}_sq_{SQUARE_SIZE}.jpg"));
    if is_newer(&output, input) {
        return output;
    }
    let size = format!("{SQUARE_SIZE}x{SQUARE_SIZE}");
    let ok = Command::new("magick")
        .arg(input)
        .args(["-auto-orient", "-gravity", "center", "-thumbnail", &format!("{size}^")])
        .args(["-extent", &size, "-quality", "90"])
        .arg(&output)
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    if ok {
        output
    } else {
        input.to_path_buf()
    }
}

fn album_art(env: &Env, player: Option<&Player>) -> Option<PathBuf> {
    let url = metadata_of(player)?.art_url()?.to_string();
    let local = if let Some(path) = url.strip_prefix("file://") {
        PathBuf::from(path)
    } else if url.starts_with("http://") || url.starts_with("https://") {
        download_art(env, &url)?
    } else {
        return None;
    };
    is_newer_or_present(&local).then(|| square_cover(env, &local))
}

fn is_newer_or_present(path: &Path) -> bool {
    fs::metadata(path).map(|m| m.len() > 0).unwrap_or(false)
}

// ---------------------------------------------------------------------------
// Cache writing
// ---------------------------------------------------------------------------

/// Write via a temp file and rename, so hyprlock never reads a partial file.
fn write_atomic(path: &Path, content: &str) -> std::io::Result<()> {
    let tmp = path.with_extension("tmp");
    fs::write(&tmp, content)?;
    fs::rename(tmp, path)
}

/// Copy the chosen art to `current.jpg` when its source changed or it is newer.
fn publish_art(env: &Env, art: &Path) -> std::io::Result<()> {
    let current = env.cache_dir.join("current.jpg");
    let source_file = env.cache_dir.join("art-source");
    let source = art.to_string_lossy().into_owned();
    let unchanged = current.exists()
        && fs::read_to_string(&source_file).ok().as_deref() == Some(source.as_str())
        && !is_newer(art, &current);
    if unchanged {
        return Ok(());
    }
    let tmp = env.cache_dir.join("current.jpg.tmp");
    fs::copy(art, &tmp)?;
    fs::rename(tmp, &current)?;
    fs::write(source_file, source)
}

/// Re-read the player and rewrite every cache file that hyprlock shows.
fn refresh(env: &Env, finder: &PlayerFinder) {
    let player = current_player(finder);
    let player = player.as_ref();

    let fields = [
        ("title", title_markup(env, player)),
        ("artist", artist_markup(env, player)),
        ("status", status_icon(status_of(player)).to_string()),
        ("player", player_display(player)),
    ];
    for (name, content) in fields {
        let _ = write_atomic(&env.cache_dir.join(name), &content);
    }

    let art = album_art(env, player).or_else(|| env.fallback_art.clone());
    if let Some(art) = art.filter(|p| is_newer_or_present(p)) {
        let _ = publish_art(env, &art);
    }
}

// ---------------------------------------------------------------------------
// Watch loop
// ---------------------------------------------------------------------------

/// Block until a player appears or vanishes or an MPRIS property changes.
fn watch(env: &Env, finder: &PlayerFinder) -> ! {
    // Single thread: callbacks only set a flag, and the loop below refreshes.
    let dirty = Arc::new(AtomicBool::new(false));

    let connection = Connection::new_session().expect("connect to session bus");
    let flag = dirty.clone();
    connection
        .add_match(
            MatchRule::new_signal("org.freedesktop.DBus", "NameOwnerChanged")
                .with_sender("org.freedesktop.DBus")
                .with_path("/org/freedesktop/DBus"),
            move |(name, _old, _new): (String, String, String), _, _| {
                if name.starts_with(MPRIS_PREFIX) {
                    flag.store(true, Ordering::Relaxed);
                }
                true
            },
        )
        .expect("match NameOwnerChanged");
    let flag = dirty.clone();
    connection
        .add_match(
            MatchRule::new_signal("org.freedesktop.DBus.Properties", "PropertiesChanged")
                .with_namespaced_path("/org/mpris/MediaPlayer2"),
            move |(_iface, _changed, _invalidated): (String, PropMap, Vec<String>), _, _| {
                flag.store(true, Ordering::Relaxed);
                true
            },
        )
        .expect("match PropertiesChanged");

    refresh(env, finder);
    loop {
        // Blocks until the bus delivers a message, then runs its callback.
        if connection.process(Duration::from_secs(3600)).is_err() {
            eprintln!("hyprlock-music: D-Bus connection lost");
            std::process::exit(1);
        }
        if dirty.swap(false, Ordering::Relaxed) {
            refresh(env, finder);
        }
    }
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

const USAGE: &str = "Usage: hyprlock-music [OPTION]

Music player information for Hyprlock.

Options:
  --title         Display song title (truncated to 29 chars)
  --artist        Display artist name (truncated to 26 chars)
  --status        Display play/pause/stop icon
  --length        Display total track length (mm:ss)
  --position      Display current position (mm:ss)
  --progress      Display progress percentage (0-100)
  --progress-image  Redraw the progress bar PNG (hyprlock reads it)
  --art           Display path to square-cropped album art
  --player        Display player name with icon
  --watch         Keep the lock-screen cache ready in the background
  --help          Show this help message";

fn main() {
    let env = Env::from_env();
    let _ = fs::create_dir_all(&env.cache_dir);
    let _ = fs::create_dir_all(&env.art_dir);
    let arg = env::args().nth(1).unwrap_or_default();
    let finder = PlayerFinder::new().expect("connect to session bus");
    let player = current_player(&finder);
    let player = player.as_ref();

    match arg.as_str() {
        "--watch" => watch(&env, &finder),
        "--title" => println!("{}", title_markup(&env, player)),
        "--artist" => println!("{}", artist_markup(&env, player)),
        "--status" => println!("{}", status_icon(status_of(player))),
        "--length" => println!("{}", mmss(length_of(player))),
        "--position" => println!("{}", mmss(position_of(player))),
        "--progress" => println!("{}", progress_percent(player)),
        "--progress-image" => {
            progress_image(&env, player);
        }
        "--art" => println!(
            "{}",
            album_art(&env, player)
                .or_else(|| env.fallback_art.clone())
                .filter(|p| is_newer_or_present(p))
                .map(|p| p.display().to_string())
                .unwrap_or_default()
        ),
        "--player" => println!("{}", player_display(player)),
        _ => println!("{USAGE}"),
    }
}
