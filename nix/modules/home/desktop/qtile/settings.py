import json
from pydantic import BaseModel
from pydantic.types import FilePath
from pathlib import Path


class QtileSettings(BaseModel):
    browser: FilePath
    wallpaper: FilePath
    terminal: FilePath


def get_settings() -> QtileSettings:
    config_file_path = Path.home() / ".config" / "qtile-injection" / "config.json"
    assert config_file_path.exists()

    with open(config_file_path, "r") as config_file:
        file_content = json.load(fp=config_file)
        return QtileSettings(**file_content)
