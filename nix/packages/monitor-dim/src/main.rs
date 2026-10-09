use std::io::{self, Read, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::time::Duration;

use calloop::{
    generic::Generic,
    signals::{Signal, Signals},
    EventLoop, Interest, Mode, PostAction,
};
use inotify::{Inotify, WatchMask};
use serde_json::Value;

// Layer-shell overlays cannot cover other overlay surfaces, their popups, or
// the lock screen reliably. Apply brightness to the final composed framebuffer
// instead. Unlike a hardware gamma ramp/CTM, these pixels also reach DisplayLink.
fn shader(percent: u8, skipped_ids: &[u64]) -> String {
    let skip = skipped_ids
        .iter()
        .map(|id| format!("wl_output == {id}"))
        .collect::<Vec<_>>()
        .join(" || ");
    let brightness = f32::from(percent.min(100)) / 100.0;
    let factor = if skip.is_empty() {
        format!("{brightness:.6}")
    } else {
        format!("({skip}) ? 1.0 : {brightness:.6}")
    };
    format!("#version 300 es\nprecision highp float;\nin vec2 v_texcoord;\nlayout(location = 0) out vec4 fragColor;\nuniform sampler2D tex;\nuniform int wl_output;\nvoid main() {{\n    vec4 color = texture(tex, v_texcoord);\n    float brightness = {factor};\n    fragColor = vec4(color.rgb * brightness, color.a);\n}}\n")
}

fn command_percent(current: u8, command: &str) -> io::Result<u8> {
    let parts: Vec<_> = command.split_whitespace().collect();
    let [op, arg] = parts.as_slice() else {
        return Err(io::Error::other("expected set/up/down <number>"));
    };
    let arg: i64 = arg.parse().map_err(io::Error::other)?;
    let value = match *op {
        "set" => arg,
        "up" => i64::from(current).saturating_add(arg),
        "down" => i64::from(current).saturating_sub(arg),
        _ => return Err(io::Error::other("expected set/up/down <number>")),
    };
    Ok(value.clamp(0, 100) as u8)
}

struct App {
    ipc: PathBuf,
    shader_path: PathBuf,
    skip: Vec<String>,
    percent: u8,
    original_cursor: i64,
    active: bool,
    dpms_off: bool,
}

impl App {
    fn request(&self, command: &str) -> io::Result<String> {
        let mut stream = UnixStream::connect(&self.ipc)?;
        stream.set_read_timeout(Some(Duration::from_secs(2)))?;
        stream.set_write_timeout(Some(Duration::from_secs(2)))?;
        stream.write_all(command.as_bytes())?;
        let mut reply = String::new();
        stream.read_to_string(&mut reply)?;
        Ok(reply)
    }

    fn keyword(&self, name: &str, value: &str) -> io::Result<()> {
        let mut reply = self.request(&format!("keyword {name} {value}"))?;
        if reply.contains("non-legacy parsers") {
            // Hyprland's Lua config backend rejects `keyword`. Use typed Lua
            // values and byte escapes so paths cannot become executable Lua.
            let value = if name == "cursor:no_hardware_cursors" {
                value.parse::<i64>().map_err(io::Error::other)?.to_string()
            } else {
                let escaped: String = value.bytes().map(|b| format!("\\{b:03}")).collect();
                format!("\"{escaped}\"")
            };
            reply = self.request(&format!(
                "eval hl.config({{[\"{}\"] = {value}}})",
                name.replace(':', ".")
            ))?;
        }
        if reply.trim() != "ok" {
            return Err(io::Error::other(reply));
        }
        Ok(())
    }

    fn option(&self, name: &str) -> io::Result<Value> {
        serde_json::from_str(&self.request(&format!("j/getoption {name}"))?)
            .map_err(io::Error::other)
    }

    fn apply(&mut self, percent: u8) -> io::Result<()> {
        let mut skipped_ids = Vec::new();
        if !self.skip.is_empty() {
            let monitors: Vec<Value> =
                serde_json::from_str(&self.request("j/monitors")?).map_err(io::Error::other)?;
            for monitor in monitors {
                if self
                    .skip
                    .iter()
                    .any(|name| monitor["name"].as_str() == Some(name.as_str()))
                {
                    if let Some(id) = monitor["id"].as_u64() {
                        skipped_ids.push(id);
                    }
                }
            }
        }
        // Atomic replacement: Hyprland must never read a partially written shader.
        let temp = self.shader_path.with_extension("tmp");
        std::fs::write(&temp, shader(percent, &skipped_ids))?;
        std::fs::rename(temp, &self.shader_path)?;
        // A hardware cursor is a separate display plane, outside the framebuffer.
        self.keyword("cursor:no_hardware_cursors", "1")?;
        self.active = true;
        self.keyword(
            "decoration:screen_shader",
            &self.shader_path.to_string_lossy(),
        )?;
        self.percent = percent;
        // A black frame still leaves DisplayLink backlights lit; power off at 0%.
        let off = percent == 0;
        if off || self.dpms_off {
            self.dispatch_dpms(!off)?;
            self.dpms_off = off;
        }
        Ok(())
    }

    fn dispatch_dpms(&self, on: bool) -> io::Result<()> {
        let action = if on { "enable" } else { "disable" };
        let reply = self.request(&format!(
            "dispatch hl.dsp.dpms({{ action = \"{action}\" }})"
        ))?;
        if reply.trim() != "ok" {
            return Err(io::Error::other(reply));
        }
        Ok(())
    }
}

impl Drop for App {
    fn drop(&mut self) {
        if self.dpms_off {
            let _ = self.dispatch_dpms(true);
        }
        if !self.active {
            return;
        }
        // Do not clear a different shader installed by another tool meanwhile.
        if let Ok(value) = self.option("decoration:screen_shader") {
            if value["str"].as_str() == self.shader_path.to_str() {
                let _ = self.keyword("decoration:screen_shader", "[[EMPTY]]");
            }
        }
        if let Ok(value) = self.option("cursor:no_hardware_cursors") {
            if value["int"].as_i64() == Some(1) {
                let _ = self.keyword(
                    "cursor:no_hardware_cursors",
                    &self.original_cursor.to_string(),
                );
            }
        }
    }
}

fn run_client(socket: &Path, verb: &str, arg: &str) -> io::Result<()> {
    let mut stream = UnixStream::connect(socket)?;
    stream.set_read_timeout(Some(Duration::from_secs(5)))?;
    stream.write_all(format!("{verb} {arg}").as_bytes())?;
    stream.shutdown(std::net::Shutdown::Write)?;
    let mut reply = String::new();
    stream.read_to_string(&mut reply)?;
    if reply.trim() != "ok" {
        return Err(io::Error::other(reply));
    }
    print!("{reply}");
    Ok(())
}

fn find_backlight_device(explicit: Option<&str>) -> Option<PathBuf> {
    let base = Path::new("/sys/class/backlight");
    if let Some(name) = explicit {
        let path = base.join(name);
        return path.is_dir().then_some(path);
    }
    std::fs::read_dir(base)
        .ok()?
        .filter_map(Result::ok)
        .map(|e| e.path())
        .next()
}

fn read_backlight_percent(dir: &Path, max: u64) -> Option<u8> {
    let value: u64 = std::fs::read_to_string(dir.join("brightness"))
        .ok()?
        .trim()
        .parse()
        .ok()?;
    Some(((u128::from(value) * 100 / u128::from(max.max(1))).min(100)) as u8)
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let runtime = PathBuf::from(std::env::var("XDG_RUNTIME_DIR")?);
    let socket = runtime.join("monitor-dim.sock");
    let args: Vec<String> = std::env::args().skip(1).collect();
    if let [verb, arg] = args.as_slice() {
        if matches!(verb.as_str(), "set" | "up" | "down") {
            return Ok(run_client(&socket, verb, arg)?);
        }
    }
    let mut skip = Vec::new();
    let mut backlight = None;
    let mut args = args.iter();
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--skip" => skip.push(args.next().ok_or("--skip needs an output name")?.clone()),
            "--backlight" => {
                backlight = Some(
                    args.next()
                        .ok_or("--backlight needs a device name")?
                        .clone(),
                )
            }
            _ => return Err(format!("unknown argument: {arg}").into()),
        }
    }

    // Register signals before taking ownership of compositor settings.
    let signals = Signals::new(&[Signal::SIGINT, Signal::SIGTERM])?;
    let mut event_loop: EventLoop<App> = EventLoop::try_new()?;
    let handle = event_loop.handle();
    let stop = event_loop.get_signal();
    handle.insert_source(signals, move |_, _, _| stop.stop())?;

    let instance = std::env::var("HYPRLAND_INSTANCE_SIGNATURE")?;
    let hypr = runtime.join("hypr").join(instance);
    let mut app = App {
        ipc: hypr.join(".socket.sock"),
        shader_path: runtime.join("monitor-dim.frag"),
        skip,
        percent: 100,
        original_cursor: 2,
        active: false,
        dpms_off: false,
    };
    let current = app.option("decoration:screen_shader")?;
    let current = current["str"].as_str().unwrap_or("");
    if !current.is_empty() && current != "[[EMPTY]]" && Some(current) != app.shader_path.to_str() {
        return Err(format!("screen shader already in use: {current}").into());
    }
    app.original_cursor = app.option("cursor:no_hardware_cursors")?["int"]
        .as_i64()
        .ok_or("missing cursor:no_hardware_cursors option")?;

    if UnixStream::connect(&socket).is_ok() {
        return Err("another monitor-dim daemon is already running".into());
    }
    let _ = std::fs::remove_file(&socket);
    let listener = UnixListener::bind(&socket)?;
    listener.set_nonblocking(true)?;
    handle.insert_source(
        Generic::new(listener, Interest::READ, Mode::Level),
        |_, listener, app| {
            while let Ok((mut stream, _)) = listener.accept() {
                // Bound malformed clients so they cannot hang dimming/shutdown forever.
                let _ = stream.set_read_timeout(Some(Duration::from_millis(200)));
                let _ = stream.set_write_timeout(Some(Duration::from_millis(200)));
                let mut buf = String::new();
                let result = (&mut stream)
                    .take(128)
                    .read_to_string(&mut buf)
                    .and_then(|_| command_percent(app.percent, &buf))
                    .and_then(|percent| app.apply(percent));
                let reply = match result {
                    Ok(()) => "ok\n".to_owned(),
                    Err(err) => format!("error: {err}\n"),
                };
                let _ = stream.write_all(reply.as_bytes());
            }
            Ok(PostAction::Continue)
        },
    )?;

    // Reapply after config reloads and hotplug, including updated --skip IDs.
    let events = UnixStream::connect(hypr.join(".socket2.sock"))?;
    events.set_nonblocking(true)?;
    let mut pending = String::new();
    let disconnect = event_loop.get_signal();
    handle.insert_source(
        Generic::new(events, Interest::READ, Mode::Level),
        move |_, events, app| {
            let mut buf = [0; 4096];
            loop {
                match (&**events).read(&mut buf) {
                    Ok(0) => {
                        disconnect.stop();
                        return Ok(PostAction::Remove);
                    }
                    Ok(n) => pending.push_str(&String::from_utf8_lossy(&buf[..n])),
                    Err(err) if err.kind() == io::ErrorKind::WouldBlock => break,
                    Err(err) => return Err(err),
                }
            }
            let mut changed = false;
            while let Some(end) = pending.find('\n') {
                let line: String = pending.drain(..=end).collect();
                changed |= ["configreloaded>>", "monitoradded>>", "monitorremoved>>"]
                    .iter()
                    .any(|prefix| line.starts_with(prefix));
            }
            if changed {
                if let Err(err) = app.apply(app.percent) {
                    eprintln!("monitor-dim: {err}");
                }
            }
            Ok(PostAction::Continue)
        },
    )?;

    let mut initial_percent = 100;
    if let Some(dir) = find_backlight_device(backlight.as_deref()) {
        let max = std::fs::read_to_string(dir.join("max_brightness"))?
            .trim()
            .parse()?;
        let inotify = Inotify::init()?;
        inotify
            .watches()
            .add(dir.join("brightness"), WatchMask::MODIFY)?;
        initial_percent = read_backlight_percent(&dir, max).unwrap_or(100);
        eprintln!("watching backlight: {}", dir.display());
        handle.insert_source(
            Generic::new(inotify, Interest::READ, Mode::Level),
            move |_, inotify, app| {
                let mut buf = [0; 4096];
                // Only drain events: the registered file descriptor is not replaced.
                let _ = unsafe { inotify.get_mut() }.read_events(&mut buf);
                if let Some(percent) = read_backlight_percent(&dir, max) {
                    if let Err(err) = app.apply(percent) {
                        eprintln!("monitor-dim: {err}");
                    }
                }
                Ok(PostAction::Continue)
            },
        )?;
    } else {
        eprintln!("monitor-dim: no backlight device found, using socket control only");
    }

    app.apply(initial_percent)?;
    println!("monitor-dim listening on {}", socket.display());
    let result = event_loop.run(None, &mut app, |_| {});
    drop(app); // Restore compositor settings on SIGTERM/SIGINT, including service restarts.
    let _ = std::fs::remove_file(socket);
    result?;
    Ok(())
}

fn main() {
    if let Err(err) = run() {
        eprintln!("monitor-dim: {err}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn brightness_limits_and_skipped_outputs() {
        assert!(shader(0, &[]).contains("float brightness = 0.000000;"));
        assert!(shader(255, &[]).contains("float brightness = 1.000000;"));
        assert!(shader(40, &[0, 7]).contains("(wl_output == 0 || wl_output == 7) ? 1.0 : 0.400000"));
        assert!(shader(40, &[]).contains("color.rgb * brightness, color.a"));
    }

    #[test]
    fn socket_commands_clamp_without_overflow_and_reject_invalid_input() {
        assert_eq!(command_percent(50, "set 0").unwrap(), 0);
        assert_eq!(command_percent(50, "up 9223372036854775807").unwrap(), 100);
        assert_eq!(
            command_percent(50, "down -9223372036854775808").unwrap(),
            100
        );
        assert_eq!(command_percent(50, "down 75").unwrap(), 0);
        for invalid in ["set", "set nope", "unknown 2", "set 20 extra"] {
            assert!(command_percent(50, invalid).is_err());
        }
    }
}
