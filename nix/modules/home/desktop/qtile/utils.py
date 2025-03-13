from functools import partialmethod


def mk_overrides(cls, **conf):
    """overrite widget parameters"""

    init_method = partialmethod(cls.__init__, **conf)
    return type(cls.__name__, (cls,), {"__init__": init_method})
