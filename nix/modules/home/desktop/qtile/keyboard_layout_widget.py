import subprocess

from libqtile.widget.generic_poll_text import GenPollText


# taken from: https://github.com/LeKSuS-04/my-arch/blob/master/dotfiles/qtile/screens.py#L32
# related reddis comment: https://www.reddit.com/r/archlinux/comments/sjgfxj/comment/ij6twko
class MyKeyboardLayout(GenPollText):
    def __init__(self, **config):
        super().__init__(**config)
        self.add_callbacks({"Button1": self.next_keyboard})

    def poll(self):
        return subprocess.check_output("xkb-switch").decode().strip()[:2].upper()

    def next_keyboard(self):
        subprocess.run(["xkb-switch", "-n"])
