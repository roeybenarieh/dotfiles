#!/bin/sh

# start picom compositor
# in charge of round edges for windows
picom &

# start alttab
# in charge of window switching using Alt+Tab key binding
alttab -d 2 &
