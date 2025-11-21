from functools import partial

import os
import subprocess
from libqtile import hook
from libqtile.bar import Gap
from libqtile.config import DropDown, Group, Key, Match, Screen, ScratchPad
from libqtile.layout.columns import Columns
from libqtile.layout.floating import Floating
from libqtile.lazy import lazy
from libqtile.utils import guess_terminal

from bar import Bar, widget_defaults
from controls import mod, keys
from settings import SETTINGS

import colors


_gap = Gap(10)
Screen = partial(
    Screen,
    bottom=_gap,
    left=_gap,
    right=_gap,
    wallpaper=SETTINGS.wallpaper,
    wallpaper_mode="fill",
)

screens = [Screen(top=Bar(i)) for i in range(4)]

layouts = [
    Columns(
        border_width=2,
        margin=4,
        border_focus=colors.BLUE_DARK,
        border_normal=colors.BG_DARK,
    )
]

floating_layout = Floating(
    border_width=2,
    border_focus=colors.BLUE_DARK,
    border_normal=colors.BG_DARK,
    float_rules=[
        *Floating.default_float_rules,
        Match(wm_class="pavucontrol"),
        Match(wm_class="confirmreset"),
        Match(wm_class="ssh-askpass"),
        Match(title="pinentry"),
        Match(title="kitty"),
    ],
)


class _Group(Group):
    def __init__(self, name: str, key: str):
        self.name = name
        self.key = key

        super().__init__(name)
        self.setup_keys()

    @classmethod
    def setup_single_keys(cls):
        toggle_term = Key(
            [mod, "shift"],
            "space",
            lazy.group["scratchpad"].dropdown_toggle("term"),
        )

        keys.append(toggle_term)

    def setup_keys(self):
        move = Key([mod], self.key, lazy.group[self.name].toscreen())
        switch = Key(
            [mod, "shift"],
            self.key,
            lazy.window.togroup(self.name, switch_group=True),
        )

        keys.extend((move, switch))


_scratchpad_defaults = dict(
    x=0.05, y=0.05, opacity=0.95, height=0.9, width=0.9, on_focus_lost_hide=False
)

_scratchpads = [
    ScratchPad("scratchpad", [DropDown("term", "kitty", **_scratchpad_defaults)])
]

_Group.setup_single_keys()
groups = _scratchpads + [_Group(lb, k) for lb, k in zip("ζπδωλσς", "1234567")]

extension_defaults = widget_defaults.copy()

dgroups_key_binder = None
dgroups_app_rules = []

follow_mouse_focus = True
bring_front_click = False
cursor_warp = False

auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True

terminal = guess_terminal(preference=["alacritty", "xterm"])

auto_minimize = False
wmname = "Qtile"


# The first bit tells Qtile to run the autostart file when it is started. The autostart file does the wallpaper, activates the compositor,
# and sets the keymap on my build the rest is the final options for qtile. Most of this stuff is pretty obvious, and doesn't really need to be
# messed with. The floating layout section is a list of window types that should automatically spawn as floating. If an app you're trying to
# glitches when spawned normally, try adding it to the list below, using the same match syntax  as with the group section. Finally at the bottom,
# the clever people who coded Qtile lie to the computer and say that Qtile is a Java window manager so it'll work correctly.
@hook.subscribe.startup
def autostart():
    # important node: the autostart.sh must be executable!
    # git saves the executable bit so you should be fine
    home = os.path.expanduser("~/.config/qtile/scripts/autostart.sh")
    subprocess.call([home])
