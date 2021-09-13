#!/bin/bash

# This script changes the screen layout according to some rules with xrandr.
# It can be hooked to udev for automatic execution on connection change.

# 1) Create this file: /etc/udev/rules.d/99-monitor-hotplug.rules
# 2) Add this line to the file above:
#    ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="/usr/local/bin/monitor-hotplug.sh"
# 3) Save this script in /usr/local/bin/monitor-hotplug.sh
# 4) Check file flags/permissions: +x 

# Some parts have been copied from stack overflow and other pages.
# This script expects an X window system with xrandr being installed.

# If the cable is plugged in or detached, root (udev) calls this script.
# Parameter -f allows normal users to trigger screen updates (including software restart, see bottom)
# Restarting software is particularely useful when dpi settings need to be adjusted, e.g. 1K -> 4K.
# Dpi adjustments requires the desktop software to be restarted in order to take effect.
# This script tries to restart some software at the bottom.

MINUTE=$( date +%M )
LAST=0
USER=$(whoami)
TTYUSER=($(who | grep tty))
# TTYUSER is actually an array with username at location 0


if [ "$1" == "-f" ]
then
  echo $( date +%H:%M:%S ) "--" "enforcing screen re-setup" >> /tmp/udev-debug.log
  echo $MINUTE > /tmp/hotplug.lock
  if [ $USER == $TTYUSER ]
  then
    notify-send "Updating screen layout"
  fi
else
  # Don't trigger this script to often
  # Udev seems to refire when xrandr disables/enables screens and if screens come back from hibernation
  if [ -f "/tmp/hotplug.lock" ]
  then
    LAST=$( cat /tmp/hotplug.lock )
  fi
  
  if [ $MINUTE -eq $LAST ]
  then
    echo $( date +%H:%M:%S ) "--" "already fired this minute, exit" >> /tmp/udev-debug.log
    exit 0
  else
    echo $MINUTE > /tmp/hotplug.lock
  fi
fi

# inspired by /etc/acpd/lid.sh and the function it sources
displaynum=`ls /tmp/.X11-unix/* | sed s#/tmp/.X11-unix/X##`
display=":$displaynum.0"
export DISPLAY=":$displaynum.0"

# from https://wiki.archlinux.org/index.php/Acpid#Laptop_Monitor_Power_Off
export XAUTHORITY=$(ps -C Xorg -f --no-header | sed -n 's/.*-auth //; s/ -[^ ].*//; p')

DEVICES=$(find /sys/class/drm/*/status)

# Declare $HDMI1, $VGA1, $LVDS1 and others if they are plugged in
# Iterates over the results of 'find' in DEVICES
while read l
do
  dir=$(dirname $l);
  status=$(cat $l);
  dev=$(echo $dir | cut -d\- -f 2-);
  
  if [ $(expr match  $dev "HDMI") != "0" ]
  then
    #REMOVE THE -X- part from HDMI-X-n
    dev=HDMI${dev#HDMI-?-}
  else
    dev=$(echo $dev | tr -d '-')
  fi

  if [ "connected" == "$status" ]
  then
    echo $( date +%H:%M:%S ) "--" $dev "connected" >> /tmp/udev-debug.log
    declare $dev="yes";
  fi
done <<< "$DEVICES"


# Set fallback settings

if [ -z "$DP1" ]
then
	xrandr --output DP-1 --off
else
	xrandr --output DP-1 --auto
fi

if [ -z "$DP2" ]
then
	xrandr --output DP-2 --off
else
	xrandr --output DP-2 --auto
fi

if [ -z "$HDMI1" ]
then
	xrandr --output HDMI-1 --off
else
	xrandr --output HDMI-1 --auto
fi



# Set the default value of dpi (HD screen)

if [ $USER == $TTYUSER ]
then
  echo "Xft.dpi: 84" > /home/${TTYUSER}/.Xresources
else
  su ${TTYUSER} -c "echo 'Xft.dpi: 84' > /home/${TTYUSER}/.Xresources"
fi 

echo "Xft.dpi: 84" | xrdb -load -



# Apply screen configurations

if [ ! -z "$HDMI1" -a ! -z "$eDP1" ]
then
  # If HDMI and internal display are present

  # Special case for regular display with specific id
  if [ $(xrandr --prop | grep '00ffffffffffff001ab37f08e5490d00' | wc -l) -eq 1 ]
  then
    echo $( date +%H:%M:%S ) "--" "Showing desktop on HDMI-1 only" >> /tmp/udev-debug.log
    xrandr --output HDMI-1 --mode 1920x1080 --primary --output eDP-1 --auto --below HDMI-1
  
  # Special case for 4K display with specific id
  elif [ $(xrandr --prop | grep '00ffffffffffff00410c8fc116080000' | wc -l) -eq 1 ]
  then
  
    echo $( date +%H:%M:%S ) "--" "Showing desktop on HDMI-1 only" >> /tmp/udev-debug.log
    xrandr --output HDMI-1 --mode 3840x2160 --primary --output eDP-1 --off

	  if [ $USER == $TTYUSER ]
	  then
		echo "Xft.dpi: 170" > /home/${TTYUSER}/.Xresources
	  else
		su ${TTYUSER} -c "echo 'Xft.dpi: 170' > /home/${TTYUSER}/.Xresources"
	  fi 

	  echo "Xft.dpi: 170" | xrdb -load -
	  randr --output HDMI-1 --primary
	   
  else
    echo $( date +%H:%M:%S ) "--" "Extending desktop to HDMI-1" >> /tmp/udev-debug.log
	  xrandr --output HDMI-1 --auto --noprimary --output eDP-1 --auto --left-of HDMI-1 --primary
  fi
elif [ ! -z "$eDP1" -a -z "$HDMI1" ]; then
  # If HDMI is not and internal display is present
  echo $( date +%H:%M:%S ) "--" "Reducing desktop to internal screen" >> /tmp/udev-debug.log
  xrandr --output eDP-1 --auto --primary --output HDMI-1 --off
  
elif [ ! -z "$eDP1" -a ! -z "$DP1" -a -z "$DP2" ]; then
  echo $( date +%H:%M:%S ) "--" "Extending desktop to DP-1" >> /tmp/udev-debug.log
  xrandr --output DP-1 --auto --noprimary --output eDP-1 --auto --left-of DP-1 --primary
  
elif [ ! -z "$eDP1" -a ! -z "$DP2" -a -z "$DP1" ]; then
  echo $( date +%H:%M:%S ) "--" "Extending desktop to DP-2" >> /tmp/udev-debug.log
  xrandr --output DP-2 --auto --noprimary --output eDP-1 --auto --left-of DP-2 --primary
  
elif [ ! -z "$eDP1" -a ! -z "$DP1" -a ! -z "$DP2" ]; then
  echo $( date +%H:%M:%S ) "--" "Showing desktop on DP-1 and DP-2" >> /tmp/udev-debug.log
  xrandr --output DP-2 --auto --noprimary --output DP-1 --auto --left-of DP-2 --primary
  
else
  echo $( date +%H:%M:%S ) "--" "Undefined monitor change detected" >> /tmp/udev-debug.log
  xrandr --auto
  sleep 5
  xrandr --auto
fi



# Restart software, if script is run as desktop user ($TTYUSER)
# Restarting the software by root with su and within the desktop showed to be tricky

sleep 1
echo $( date +%H:%M:%S ) "--" "Restarting OpenBox" >> /tmp/udev-debug.log

if [ $USER == $TTYUSER ]
then
	openbox --restart

	killall pcmanfm-qt
	pcmanfm-qt -d --desktop --profile=lxqt &
	
	killall lxqt-panel
	retVal=$?
	if [ $retVal -eq 0 ]; then
    	lxqt-panel &
	fi
	
	killall firefox 
	retVal=$?
	if [ $retVal -eq 0 ]; then
    	firefox &
	fi

	killall thunderbird 
	retVal=$?
	if [ $retVal -eq 0 ]; then
    	thunderbird &
	fi

	killall element-desktop 
	retVal=$?
	if [ $retVal -eq 0 ]; then
    	element-desktop --hidden &
	fi

	killall nm-applet
	retVal=$?
	if [ $retVal -eq 0 ]; then
		sleep 2
    	nm-applet &
	fi

	killall slack
	retVal=$?
	if [ $retVal -eq 0 ]; then
    	slack -u -s &
	fi

	killall lxqt-notificationd

else
	su ${TTYUSER} -c "openbox --restart"
fi


chmod 777 /tmp/udev-debug.log
chmod 777 /tmp/hotplug.lock
echo "$( date +%M )" > /tmp/hotplug.lock
