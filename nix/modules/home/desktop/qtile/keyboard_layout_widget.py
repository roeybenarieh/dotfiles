import subprocess
from libqtile import widget


# taken from: https://github.com/LeKSuS-04/my-arch/blob/master/dotfiles/qtile/screens.py#L32
# related reddis comment: https://www.reddit.com/r/archlinux/comments/sjgfxj/comment/ij6twko
class MyKeyboardLayout(widget.base.ThreadPoolText):
    def __init__(self, **config):
        super().__init__(**config)
        self.add_callbacks({"Button1": self.next_keyboard})

    def poll(self):
        return subprocess.check_output("xkb-switch").decode().strip()[:2].upper()

    def next_keyboard(self):
        subprocess.run(["xkb-switch", "-n"])
        self.tick()
