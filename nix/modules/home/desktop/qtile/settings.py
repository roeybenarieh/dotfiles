import json
from pydantic import BaseModel
from pydantic.types import FilePath
from pathlib import Path


class QtileSettings(BaseModel):
    lock_screen_command: str
    browser: str
    wallpaper: FilePath
    terminal: str
    font: str
    screenshot_dir: Path
    network_manager: str
    task_manager: str
    audio_visualizer: str
    auidio_controller: str
    application_launcher: str
    simple_monitors_manager: str


def __get_settings() -> QtileSettings:
    config_file_path = Path.home() / ".config" / "qtile-injection" / "config.json"
    assert config_file_path.exists()

    with open(config_file_path, "r") as config_file:
        file_content = json.load(fp=config_file)
        print(file_content)
        return QtileSettings(**file_content)


SETTINGS = __get_settings()
