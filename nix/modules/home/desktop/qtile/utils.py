from functools import partialmethod
from libqtile.utils import send_notification


def notify(*args, **kwargs):
    send_notification(title="qtile debug notification", message=str(args), urgent=True)


def mk_overrides(cls, **conf):
    """overrite widget parameters"""

    init_method = partialmethod(cls.__init__, **conf)
    return type(cls.__name__, (cls,), {"__init__": init_method})
