from colors import RED_DARK
from libqtile.widget.generic_poll_text import GenPollText
from pydexcom import Dexcom, Region, GlucoseReading
from pathlib import Path
from typing import Optional
from dataclasses import dataclass


@dataclass
class Config:
    dexcom_username: str
    dexcom_password: str


def get_config() -> Optional[Config]:
    # path to config
    config_path = Path.home() / ".local" / "state" / "qtile-config"
    config_path.mkdir(parents=True, exist_ok=True)

    # config file
    config_file = config_path / "config.txt"
    config_file.touch()

    # read lines
    lines = config_file.read_text().split("\n")
    if len(lines) < 2:
        return None

    # return configuration
    return Config(
        dexcom_username=lines[0],
        dexcom_password=lines[1],
    )


class DexcomGlucose(GenPollText):
    def poll(self):
        glucose_reading = self.__get_glucose_reading()
        if isinstance(glucose_reading, str):
            return glucose_reading

        if glucose_reading.value < 80 or 130 < glucose_reading.value:
            self.background = RED_DARK

        return str(glucose_reading.value) + glucose_reading.trend_arrow

    def __get_glucose_reading(self) -> GlucoseReading | str:
        config = get_config()
        if not config:
            return "???no-cred"

        try:
            dexcom = Dexcom(
                password=config.dexcom_password,
                username=config.dexcom_username,
                region=Region.OUS,
            )
            glucose_reading = dexcom.get_current_glucose_reading()
        except Exception:
            return "???http-err"
        if not glucose_reading:
            return "---no-data"

        return glucose_reading
