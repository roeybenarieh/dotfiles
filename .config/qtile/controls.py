from libqtile.config import Click, Drag, Key
from libqtile.lazy import lazy
from pathlib import Path
import os

# common key maps
mod = "mod4"
shift = "shift"
alt = "mod1"
enter_key = "Return"
space = "space"
control = "control"

# dependencies
_screenshot_dir = Path.home() / "Pictures" / "Screenshots"
_screenshot_dir.mkdir(parents=True, exist_ok=True)
os.environ["CM_LAUNCHER"] = "rofi"    # make clipmenu output clip selection to stdout
os.environ["CM_HISTLENGTH"] = "10"    # number of lines of clipboard history to show
os.environ["CM_OUTPUT_CLIP"] = "true" # launch clipmenu with rofi

mouse = [
    Drag(
        [mod],
        "Button1",
        lazy.window.set_position_floating(),
        start=lazy.window.get_position(),
    ),
    Drag(
        [mod], "Button3", lazy.window.set_size_floating(), start=lazy.window.get_size()
    ),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

keys = [
    Key([mod], "e", lazy.spawn("xdg-open .")),
    Key([mod], "v", lazy.spawn("clipmenu")),
    Key([mod], "h", lazy.spawn("kitty -e nmtui")),
    Key([mod, "shift"], "v", lazy.spawn("pavucontrol")),
    Key([mod], "l", lazy.spawn("dm-tool lock")),
    Key([mod], "f", lazy.window.toggle_floating()),
    Key([mod], "b", lazy.spawn("firefox")),
    Key(
        [],
        "Print",
        lazy.spawn(f"flameshot screen --clipboard --path {_screenshot_dir}"),
    ),  # screenshot
    Key(
        [mod, shift],
        "s",
        lazy.spawn(f"flameshot gui --clipboard --path {_screenshot_dir}"),
    ),  # partial screenshot
    # Key([mod], space, lazy.layout.next()),
    Key([alt], "Tab", lazy.layout.next()),
    Key([mod, "shift"], "h", lazy.layout.shuffle_left()),
    Key([mod], "n", lazy.layout.normalize()),
    Key([mod], enter_key, lazy.spawn("alacritty")),
    Key([mod], "Tab", lazy.next_layout()),
    Key([mod], "m", lazy.window.toggle_maximize(), desc="Toggle maximize"),
    Key([], "F11", lazy.window.toggle_fullscreen(), desc="Toggle fullscreen"),
    Key([mod], "w", lazy.window.kill()),
    Key([alt], "F4", lazy.window.kill()),
    Key([control], "escape", lazy.spawn("alacritty -e btop")),
    Key([mod, control], "r", lazy.reload_config()),
    Key([mod, control], "q", lazy.shutdown()),
    Key([mod], "r", lazy.spawncmd()),
    Key([alt], space, lazy.spawn("rofi -show drun")),
    # keyboard layout
    Key(
        [mod],
        space,
        lazy.widget["keyboardlayout"].next_keyboard(),
        desc="Next keyboard layout.",
    ),
    # Backlight
    Key([], "XF86MonBrightnessUp", lazy.spawn("brightnessctl set +5%")),
    Key([], "XF86MonBrightnessDown", lazy.spawn("brightnessctl set 5%-")),
    # Volume
    Key([], "XF86AudioMute", lazy.spawn("pamixer --toggle-mute")),  # mute volume
    Key([], "XF86AudioLowerVolume", lazy.spawn("pamixer --decrease 5")),  # -5 volume
    Key([], "XF86AudioRaiseVolume", lazy.spawn("pamixer --increase 5")),  # +5 volume
    Key([], "XF86AudioPlay", lazy.spawn("playerctl play-pause")),  # pause/play
    Key([], "XF86AudioNext", lazy.spawn("playerctl next")),  # go to next play
    Key([], "XF86AudioPrev", lazy.spawn("playerctl previous")),  # go to previous play
    # resizing windows
    Key(
        [mod, control],
        "Right",
        lazy.layout.grow_right(),
        lazy.layout.grow(),
        lazy.layout.increase_ratio(),
        lazy.layout.delete(),
    ),
    Key(
        [mod, control],
        "Left",
        lazy.layout.grow_left(),
        lazy.layout.shrink(),
        lazy.layout.decrease_ratio(),
        lazy.layout.add(),
    ),
    Key(
        [mod, control],
        "Up",
        lazy.layout.grow_up(),
        lazy.layout.shrink(),
        lazy.layout.decrease_ratio(),
        lazy.layout.add(),
    ),
    Key(
        [mod, control],
        "Down",
        lazy.layout.grow_down(),
        lazy.layout.shrink(),
        lazy.layout.decrease_ratio(),
        lazy.layout.add(),
    ),
]
