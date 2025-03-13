import colors
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


def is_glucose_in_range(glucose_reading: int):
    return 80 < glucose_reading < 130


class DexcomHandler:
    last_config: Config | None = None
    last_generated_client: Dexcom | None = None

    @classmethod
    def get_client(cls) -> Dexcom | None:
        config = get_config()
        if not config:
            return None

        # recycle old client
        if cls.last_config is not None and cls.last_config == config:
            return cls.last_generated_client

        # generate new client
        client = Dexcom(
            password=config.dexcom_password,
            username=config.dexcom_username,
            region=Region.OUS,
        )
        cls.last_generated_client = client
        cls.last_config = config
        return client


class DexcomGlucose(GenPollText):
    def poll(self):
        glucose_reading = self.__get_glucose_reading()
        if isinstance(glucose_reading, str):
            return glucose_reading

        if not is_glucose_in_range(glucose_reading.value):
            self.background = colors.RED_DARK
        else:
            self.background = colors.BG_DARK

        return str(glucose_reading.value) + glucose_reading.trend_arrow

    def __get_glucose_reading(self) -> GlucoseReading | str:
        client = DexcomHandler.get_client()
        if not client:
            return "???no-cred"
        try:
            glucose_reading = client.get_current_glucose_reading()
        except Exception:
            return "???http-err"
        if not glucose_reading:
            return "---no-data"

        return glucose_reading


class DexcomInRangePercentage(GenPollText):
    def poll(self):
        glucose_readings = self.__get_glucose_readings()
        if isinstance(glucose_readings, str):
            return glucose_readings

        # calculate in range percentage
        glucose_values = [glucose_reading.value for glucose_reading in glucose_readings]
        in_range_values = list(filter(is_glucose_in_range, glucose_values))
        in_range_percentage = int(len(in_range_values) / len(glucose_values) * 100)

        # calculate backgound color
        self.background = colors.get_gradient_color(
            min_val=50,
            max_val=90,
            current_value=in_range_percentage,
        )

        return f"{in_range_percentage}%"

    def __get_glucose_readings(self) -> list[GlucoseReading] | str:
        client = DexcomHandler.get_client()
        if not client:
            return "???no-cred"
        try:
            glucose_reading = client.get_glucose_readings(minutes=60 * 24)
        except Exception:
            return "???http-err"
        if not glucose_reading:
            return "---no-data"

        return glucose_reading
