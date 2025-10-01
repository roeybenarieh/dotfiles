import re
import subprocess

from keyboard_layout_widget import MyKeyboardLayout
from libqtile import bar, widget
from libqtile.widget.nvidia_sensors import NvidiaSensors
from libqtile.lazy import lazy
from libqtile.widget import PulseVolume

import colors
import dexcom_widget
from utils import mk_overrides
from settings import SETTINGS

widget_defaults = dict(
    font=SETTINGS.font,
    fontsize=12,
    padding=12,
    background=colors.BG_DARK.with_alpha(0.9),
    foreground=colors.TEXT_LIGHT,
)

DexcomGlucose = mk_overrides(
    dexcom_widget.DexcomGlucose,
    update_interval=10,  # update every 10s
)

KeyboardLayout = mk_overrides(
    MyKeyboardLayout,
    text="UNK",
    update_interval=0.1,
)

# TODO: get gpu usage%
NvidiaTemp = mk_overrides(NvidiaSensors, format="{temp}°C", update_interval=5)

DexcomInRangePercentage = mk_overrides(
    dexcom_widget.DexcomInRangePercentage,
    update_interval=60 * 5,  # update every 5min
)

Volume = mk_overrides(
    PulseVolume,
    mouse_callbacks={
        "Button2": lazy.spawn(SETTINGS.auidio_controller),
        "Button3": lazy.spawn(SETTINGS.audio_visualizer),
    },
)


Battery = mk_overrides(
    widget.Battery,
    format="⚡{percent:2.0%}",
    background=colors.BG_DARK.with_alpha(0.7),
    foreground=colors.TEXT_LIGHT,
    low_background=colors.RED_DARK.with_alpha(0.7),
    low_percentage=0.1,
)

CPUGraph = mk_overrides(
    widget.CPUGraph,
    type="line",
    line_width=1,
    border_width=0,
)

GroupBox = mk_overrides(
    widget.GroupBox,
    highlight_method="line",
    disable_drag=True,
    other_screen_border=colors.BLUE_VERY_DARK,
    other_current_screen_border=colors.BLUE_VERY_DARK,
    this_screen_border=colors.BLUE_DARK,
    this_current_screen_border=colors.BLUE_DARK,
    block_highlight_text_color=colors.TEXT_LIGHT,
    highlight_color=[colors.BG_LIGHT, colors.BG_LIGHT],
    inactive=colors.TEXT_INACTIVE,
    active=colors.TEXT_LIGHT,
)

Mpris2 = mk_overrides(
    widget.Mpris2,
    objname="org.mpris.MediaPlayer2.spotify",
    format="{xesam:title} - {xesam:artist}",
)

Memory = mk_overrides(
    widget.Memory,
    format="{MemUsed: .1f}GB",
    measure_mem="G",
    mouse_callbacks={"Button1": lazy.spawn(SETTINGS.task_manager)},
)

TaskList = mk_overrides(
    widget.TaskList,
    icon_size=0,
    fontsize=12,
    borderwidth=0,
    margin=0,
    padding=4,
    txt_floating="",
    highlight_method="block",
    title_width_method="uniform",
    spacing=8,
    foreground=colors.TEXT_LIGHT,
    background=colors.BG_DARK.with_alpha(0.8),
    border=colors.BG_DARK.with_alpha(0.9),
)

Separator = mk_overrides(widget.Spacer, length=4)
Clock = mk_overrides(
    widget.Clock,
    format="%A, %b %-d %H:%M",
    mouse_callbacks={
        "Button1": lazy.spawn("xdg-open https://calendar.google.com"),
    },
)


QuickExit = mk_overrides(widget.QuickExit, default_text="⏻", countdown_format="{}")

Prompt = mk_overrides(
    widget.Prompt,
    prompt=">",
    bell_style="visual",
    background=colors.BG_DARK,
    foreground=colors.TEXT_LIGHT,
    padding=8,
)

Systray = mk_overrides(
    widget.Systray,
    icon_size=14,
    padding=8,
)


class Bar(bar.Bar):
    _widgets = [
        GroupBox,
        Separator,
        TaskList,
        Separator,
        Prompt,
        Mpris2,
        DexcomGlucose,
        DexcomInRangePercentage,
        Battery,
        NvidiaTemp,
        Memory,
        CPUGraph,
        Separator,
        widget.PulseVolume,
        KeyboardLayout,
        Clock,
        Separator,
        QuickExit,
    ]

    def __init__(self, id_):
        self.id = id_
        super().__init__(
            widgets=self._build_widgets(),
            size=24,
            background=colors.BG_DARK,
            margin=[0, 0, 8, 0],
        )

    def is_desktop(self):
        machine_info = subprocess.check_output(
            ["hostnamectl", "status"], universal_newlines=True
        )
        m = re.search(r"Chassis: (\w+)\s.*\n", machine_info)
        chassis_type = "desktop" if m is None else m.group(1)

        return chassis_type == "desktop"

    def _build_widgets(self):
        if self.is_desktop():
            self._widgets = [w for w in self._widgets if w != Battery]

        widgets = [widget_cls() for widget_cls in self._widgets]
        if self.id == 0:
            widgets.insert(12, Systray())

        return widgets
