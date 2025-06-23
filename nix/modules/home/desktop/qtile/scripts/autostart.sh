#!/bin/sh

# start picom compositor - only if not in xrdp session(because it is very hevy in remote sessions)
# in charge of round edges for windows
if [ -z "$XRDP_SESSION" ]; then
	picom -b
fi

# start alttab
# in charge of window switching using Alt+Tab key binding
alttab -d 2 &
