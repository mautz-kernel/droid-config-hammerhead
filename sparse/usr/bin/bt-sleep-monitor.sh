#!/bin/bash
#title           : bt-sleep-monitor
#description     : Bluetooth 'LowPowerMode' monitor for SailfishOS ports that face a bluetooth wakelock bug.
#author          : minimec
#date            : 20171012
#version         : 0.7 ('next generation') / 'Talk Maemo'
#usage           : Usage: bt-sleep-monitor {start|stop|status}
#notes           : Can be used as standalone program or as systemd service
#==============================================================================
#How it works... : A dbus-monitor process is listening for different dbus events in parallel:
#                    - Bluetooth power on/off
#                    - Bluetooth connections
#                    - Display events
#                  When an event is triggered the program will decide whether to enable/disable 
#                  or temporarily disable bluetooth suspend (low power mode).
#                  If bluetooth is powered and in low power mode, a display event will disable suspend mode for a given time.
#                  In case there is no bluetooth connection after that time, suspend mode is enabled again. See $BTACTIVE.    
#Monitor...      : After having launched the script in a console, you can follow a log, as long the console stays open. 
#==============================================================================

## Variables
BTACTIVE=60
BTPOWER=$(connmanctl technologies | sed -n -e '/bluetooth/,+5p' | grep Powered | awk '{print $3; exit}')
BTCONNECT=$(hcitool con | grep ACL)
SLEEPTIMER=$(cat /tmp/sleeptimer)

## Functions
bluepower() {
    if [ "$BTPOWER" == "True" ] ; then
        echo "0" > /proc/bluetooth/sleep/lpm
        printf "bluepower 'on' (timer) \n"
        sleeptimer &
    else
        echo "1" > /proc/bluetooth/sleep/lpm
        echo "0" > /tmp/sleeptimer
        printf "bluepower 'off' (on) \n"
    fi
}

blueconnect() {
    sleep 2
    if  [ "$(hcitool con | grep ACL)" == "" ] ; then
#        echo "1" > /proc/bluetooth/sleep/lpm
        printf "blueconnect 'no connection' (timer) \n"
        sleeptimer &
    else
        printf "blueconnect 'connection' (-) \n"
    fi 
}

display() {
    if [ "$BTPOWER" == "True" ] && [ "$BTCONNECT" == "" ] && [ "$SLEEPTIMER" == "0" ] ; then
        echo "0" > /proc/bluetooth/sleep/lpm
        printf "display 'event' (timer) \n" 
        sleeptimer &
    else
        printf "display 'event' (-) \n"
    fi     
}

sleeptimer() {
    echo "$(($(cat /tmp/sleeptimer)+1))" > /tmp/sleeptimer 
    sleep $BTACTIVE
    if [ "$(cat /tmp/sleeptimer)" -gt "1" ] ; then
        echo "$(($(cat /tmp/sleeptimer)-1))" > /tmp/sleeptimer
        exit 0
    elif [ "$(cat /tmp/sleeptimer)" -eq "0" ] ; then
        exit 0
    elif [ "$(hcitool con | grep ACL)" == "" ] ; then
        echo "1" > /proc/bluetooth/sleep/lpm
        printf "timer 'no connection' (on) \n"
        echo "0" > /tmp/sleeptimer
    else
        echo "0" > /tmp/sleeptimer
    fi
    exit 0
}

dbuslisten() {
    # Create PID-file
    echo $(pidof bt-sleep-monitor) > /var/run/bt-sleep-monitor.pid 

    # Dbus listener
    WATCH1="path='/net/connman/technology/bluetooth',interface='net.connman.Technology',member='SetProperty'"
    WATCH2="interface='org.bluez.Device',member='PropertyChanged'"
    WATCH3="interface='com.nokia.mce.signal',member='display_status_ind'"

    dbus-monitor --system "${WATCH1}" "${WATCH2}" "${WATCH3}" | \
    awk '
    /member=SetProperty/ { system("'$0' --bluepower") }
    /member=PropertyChanged/ { system("'$0' --blueconnect") }
    /member=display_status_ind/ { system("'$0' --display") }
    '
    }

start() {
    echo "1" > /proc/bluetooth/sleep/lpm
    echo "0" > /tmp/sleeptimer
    printf "Bluetooth Sleep Monitor started (on)\n"
    dbuslisten &
}

stop() {
    pkill -P $(cat /var/run/bt-sleep-monitor.pid) && rm /var/run/bt-sleep-monitor.pid
    echo "0" > /proc/bluetooth/sleep/lpm
    rm /tmp/sleeptimer
    printf "Bluetooth Sleep Monitor stopped (off)\n"
    killall bt-sleep-monitor
}

status() {
    if [ -e /var/run/bt-sleep-monitor.pid ]; then
       echo Bluetooth Sleep Monitor is running, pid=`cat /var/run/bt-sleep-monitor.pid`
    else
       echo Bluetooth Sleep Monitor is NOT running
       exit 1
    fi
}


## Main

# check for a command switch and call different functionality if it is found
if [[ $# -eq 1 && $1 == "--bluepower" ]]; then
    bluepower
elif [[ $# -eq 1 && $1 == "--blueconnect" ]]; then
    blueconnect
elif [[ $# -eq 1 && $1 == "--display" ]]; then
    display
elif [[ $# -eq 1 && $1 == "start" ]]; then
    start
elif [[ $# -eq 1 && $1 == "stop" ]]; then
    stop
elif [[ $# -eq 1 && $1 == "status" ]]; then
    status
else
    echo "Usage: $0 {start|stop|status}"
fi
