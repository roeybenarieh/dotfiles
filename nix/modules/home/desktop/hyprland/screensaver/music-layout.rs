// Scale the complete music panel uniformly, using its 1920x1080 reference design.
use std::{
    env,
    error::Error,
    fs,
    io::{self, Read},
    path::Path,
};

fn render(template: &str, name: &str, width: f64, height: f64) -> Result<String, Box<dyn Error>> {
    if width <= 0.0 || height <= 0.0 || !width.is_finite() || !height.is_finite() {
        return Err("invalid monitor dimensions".into());
    }
    let scale = (width / 1920.0).min(height / 1080.0);
    let mut output = String::new();
    for block in template.split_inclusive("}\n") {
        let left_aligned = block.lines().any(|line| {
            line.trim()
                .split_once('=')
                .is_some_and(|(key, value)| key.trim() == "halign" && value.trim() == "left")
        });
        for line in block.lines() {
            if let Some((key, value)) = line.trim().split_once('=') {
                let (key, value) = (key.trim(), value.trim());
                let value = match key {
                    "monitor" => name.to_owned(),
                    "position" | "size" if value.contains(',') => {
                        let parts: Vec<_> = value.split(',').collect();
                        if parts.len() != 2 {
                            return Err("expected two layout dimensions".into());
                        }
                        let mut dimensions = Vec::new();
                        for (axis, (part, reference)) in
                            parts.iter().zip([1920.0, 1080.0]).enumerate()
                        {
                            let part = part.trim();
                            let pixels = if let Some(percent) = part.strip_suffix('%') {
                                percent.parse::<f64>()? * reference / 100.0
                            } else {
                                part.parse::<f64>()?
                            };
                            let scaled = if key == "position" && axis == 0 && left_aligned {
                                // Keep a left-aligned label's edge relative to the
                                // centered panel, rather than the monitor's edge.
                                width / 2.0 + (pixels - 960.0) * scale
                            } else {
                                pixels * scale
                            };
                            dimensions.push(format!("{:.0}", scaled.round()));
                        }
                        dimensions.join(", ")
                    }
                    "size" | "font_size" | "border_size" | "rounding" => {
                        let pixels = value.parse::<f64>()?;
                        if pixels > 0.0 {
                            format!("{:.0}", (pixels * scale).round().max(1.0))
                        } else {
                            value.to_owned()
                        }
                    }
                    _ => value.to_owned(),
                };
                output.push_str(&format!("    {key} = {value}\n"));
            } else {
                output.push_str(line);
                output.push('\n');
            }
        }
    }
    Ok(output)
}

fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<_> = env::args().collect();
    if args.len() != 3 {
        return Err("usage: hyprlock-music-layout TEMPLATE OUTPUT < monitors.tsv".into());
    }
    let template = fs::read_to_string(&args[1])?;
    let mut monitors = String::new();
    io::stdin().read_to_string(&mut monitors)?;
    let mut output = String::new();
    for monitor in monitors.lines() {
        let fields: Vec<_> = monitor.split('\t').collect();
        if fields.len() != 4 {
            return Err("invalid monitor record".into());
        }
        let (mut width, mut height) = (fields[1].parse::<f64>()?, fields[2].parse::<f64>()?);
        if fields[3].parse::<u8>()? % 2 == 1 {
            std::mem::swap(&mut width, &mut height);
        }
        // Hyprlock renders in physical pixels; do not divide by compositor scale.
        output.push_str(&render(&template, fields[0], width, height)?);
    }
    if output.is_empty() {
        return Err("no active monitors".into());
    }
    let destination = Path::new(&args[2]);
    fs::create_dir_all(
        destination
            .parent()
            .ok_or("output needs a parent directory")?,
    )?;
    fs::write(destination, output)?;
    Ok(())
}

#[test]
fn panel_and_art_fit_every_aspect_ratio() {
    let template = "shape {\n    monitor = \n    size = 26.04%, 12.96%\n    position = 0%, 3.70%\n}\nimage {\n    monitor = \n    size = 100\n    border_size = 0\n    position = -9.4%, 5.55%\n}\n";
    for (width, height) in [
        (320.0, 240.0),
        (640.0, 480.0),
        (1280.0, 800.0),
        (1920.0, 1080.0),
        (3440.0, 1440.0),
        (3840.0, 2160.0),
        (1080.0, 1920.0),
    ] {
        let output = render(template, "test", width, height).unwrap();
        let numbers: Vec<Vec<f64>> = output
            .lines()
            .filter_map(|line| {
                let (key, value) = line.trim().split_once(" = ")?;
                ["size", "position", "border_size"].contains(&key).then(|| {
                    value
                        .split(',')
                        .map(|part| part.trim().parse().unwrap())
                        .collect()
                })
            })
            .collect();
        let (panel, bottom, art, border, position) = (
            &numbers[0],
            numbers[1][1],
            numbers[2][0],
            numbers[3][0],
            &numbers[4],
        );
        assert!(panel[0] <= width && bottom >= 0.0 && bottom + panel[1] <= height);
        assert!(position[0].abs() + art / 2.0 + border <= panel[0] / 2.0);
        // Hyprlock aligns the entire image framebuffer, including both borders.
        let image_height = art + 2.0 * border;
        assert!(position[1] >= bottom && position[1] + image_height <= bottom + panel[1]);
        assert!(
            (position[1] + image_height / 2.0 - (bottom + panel[1] / 2.0)).abs() <= 1.0,
            "album art is not vertically centered at {width}x{height}"
        );
        assert_eq!(output.matches("monitor = test").count(), 2);
    }
    assert!(render(template, "test", 3840.0, 2160.0)
        .unwrap()
        .contains("size = 200\n"));
    assert!(render(template, "test", 0.0, 1080.0).is_err());
}

#[test]
fn long_titles_start_after_album_art() {
    // Both property orderings must keep the same left edge, regardless of
    // title width. Centering the label would move this edge as titles change.
    for label in [
        "label {\n halign = left\n position = 44.27%, 12.78%\n}\n",
        "label {\n position = 44.27%, 12.78%\n halign = left\n}\n",
    ] {
        for (width, height) in [
            (320.0, 240.0),
            (1280.0, 800.0),
            (1080.0, 1920.0),
            (3440.0, 1440.0),
            (3840.0, 2160.0),
        ] {
            let output = render(label, "test", width, height).unwrap();
            let x: f64 = output
                .lines()
                .find_map(|line| {
                    line.trim()
                        .strip_prefix("position = ")?
                        .split(',')
                        .next()?
                        .parse()
                        .ok()
                })
                .unwrap();
            let scale = (width / 1920.0).min(height / 1080.0);
            let art_right = width / 2.0
                + (-180.48 * scale).round()
                + (100.0 * scale).round().max(1.0) / 2.0
                + (3.0 * scale).round().max(1.0);
            assert!(x > art_right, "title overlaps art at {width}x{height}");
            assert!((x - (width / 2.0 - 110.016 * scale)).abs() <= 0.5);
        }
    }
}
