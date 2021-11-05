# monitor-hotplug

Srcipt for automatic screen reconfiguration upon connection (plugged in).

This script changes the screen layout according to some rules with xrandr.
It can be hooked to udev for automatic execution on connection change:

1) Create this file: /etc/udev/rules.d/99-monitor-hotplug.rules
2) Add this line to the file above:
```ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="/usr/local/bin/monitor-hotplug.sh"```
3) Save this script in /usr/local/bin/monitor-hotplug.sh
4) Check file flags/permissions: +x 

*Some parts have been copied from stack overflow and other pages.*

This script expects an X window system with xrandr being installed.
If the monitor cable is plugged in or detached, root (udev) calls this script.

Parameter -f allows normal users to trigger screen updates (including software restart, see bottom)
Restarting software is particularly useful when dpi settings need to be adjusted, e.g. 1K -> 4K.
Dpi adjustments requires the desktop software to be restarted in order to take effect.
This script tries to restart some software, see bottom.
