#!/bin/sh

# start alttab
# in charge of window switching using Alt+Tab key binding
alttab -d 2 &

# start libinput-gestures, for better touchpad gestures
if command -v libinput-gestures; then
	# Command exists, so run it
	libinput-gestures &
fi
