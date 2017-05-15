#!/bin/bash
#title           : bt-sleep-monitor.sh
#description     : Bluetooth 'LowPowerMode' monitor for SailfishOS ports that face a bluetooth wakelock bug.
#author          : minimec
#date            : 20170206
#version         : 0.3 (2nd release/code cleaned/with logfile for testing)  
#usage           : ./bash bt-sleep-monitor.sh &  (first login to a root console with 'devel-su')
#kill script     : devel-su killall bt-sleep-monitor.sh dbus-monitor 
#follow log      : tail -f /dev/shm/bt-sleep-monitor.log
#notes           : Best use as systemd service 
#==============================================================================
#How it works... : LowPowerMode is disabled in two cases:
#                    - by enabling the bluetooth adapter, in case it is 'disabled'.  
#                    - by powering on the display, in case the adapter is 'enabled'.
#                  The script switches between these modes automatically.
#                  After an 'action' is triggered you have 120sec. (default value) to connect a device.  
#                  In case a device is connected, the script listens for 'disconnect' and will enable LPM again afterwards.
#==============================================================================

    
## DEFAULTS
# This value defines the default wakeup time (in seconds) before 'lpm mode' is set again.
BTACTIVE=120
# Default name for log file
LOGFILE=/dev/shm/bt-sleep-monitor.log
# Create log file
echo "$(date): Log started" > $LOGFILE
chmod 777 $LOGFILE
# Bluetooth 'LowPowerMode' default
echo "$(date): Set 'lpm=1' as default" >> $LOGFILE
echo "1" > /proc/bluetooth/sleep/lpm


### MAIN loop
while true; do

## SCRIPT

    # Check if bluetooth adapter is enabled/disabled
    if [ "$(connmanctl technologies | sed -n -e '/bluetooth/,+5p' | grep Powered | awk '{print $3; exit}')" == "False" ] ; then
        # BLUETOOTH ADAPTER DISABLED: (start bluetooth listener)
        echo "$(date): Bluetooth disabled (starting bluetooth listener)" >> $LOGFILE
        dbus-monitor --system "interface='net.connman.Technology',member='SetProperty'" |
        while read -r line; do
            if [ "$(echo $line | awk 'END {print $NF}')" == "true" ]; then
                # Action 'bluetooth on' triggered (set lpm=0 for a certain time before we look for a connection)
                echo "$(date): Action 'bluetooth on' (set 'lpm=0' for $BTACTIVE seconds)" >> $LOGFILE
                echo "0" > /proc/bluetooth/sleep/lpm
                sleep $BTACTIVE
                # Kill obsolete listener
                pkill -g $$ dbus-monitor
                # We check if a device is connetced. Otherwise we go to sleep.
                if  [ "$(hcitool con | grep \>)" == "" ] ; then
                    echo "1" > /proc/bluetooth/sleep/lpm
                    echo "$(date): No connection after $BTACTIVE seconds (set 'lpm=1')" >> $LOGFILE
                else
                    # We have a connection. If device disconnects, we go to sleep.
                    echo "$(date): Device connected (listening for 'disconnect')" >> $LOGFILE
                    dbus-monitor --system "interface='org.bluez.Control',member='PropertyChanged'" |
                    while read -r line; do
                        if [ "$(echo $line | awk 'END {print $NF}')" == "false" ]; then
                            echo "1" > /proc/bluetooth/sleep/lpm
                            echo "$(date): Device disconnected (set 'lpm=1')" >> $LOGFILE
                            # Kill obsolete listener
                            pkill -g $$ dbus-monitor
                        fi
                    done
                fi
            fi
        done
    else
        # BLUETOOTH ADAPTER ENABLED: (start 'display on' listener)
        echo "$(date): Bluetooth enabled (starting 'display on' listener)" >> $LOGFILE
        dbus-monitor --system "interface='com.nokia.mce.signal',member='display_status_ind'" |
        while read -r line; do
            if [ "$(echo $line | awk -F\" '{print $2}')" == "on" ]; then
                # Action 'display on' triggered (set lpm=0 for a certain time before we look for a connection)
                echo "$(date): Action 'display on' (set 'lpm=0' for $BTACTIVE seconds)" >> $LOGFILE
                echo "0" > /proc/bluetooth/sleep/lpm
                sleep $BTACTIVE
                # Kill obsolete listener
                pkill -g $$ dbus-monitor
                # We check if a device is connetced. Otherwise we go to sleep.
                if  [ "$(hcitool con | grep \>)" == "" ] ; then
                    echo "1" > /proc/bluetooth/sleep/lpm
                    echo "$(date): No connection after $BTACTIVE seconds (set 'lpm=1')" >> $LOGFILE
                else
                    # We have a connection. If device disconnects, we go to sleep.
                    echo "$(date): Device connected (listening for 'disconnect')" >> $LOGFILE
                    dbus-monitor --system "interface='org.bluez.Control',member='PropertyChanged'" |
                    while read -r line; do
                        if [ "$(echo $line | awk 'END {print $NF}')" == "false" ]; then
                            echo "1" > /proc/bluetooth/sleep/lpm
                            echo "$(date): Device disconnected (set 'lpm=1')" >> $LOGFILE
                            # Kill obsolete listener
                            pkill -g $$ dbus-monitor
                        fi
                    done
                fi
            fi
        done
    fi
## SCRIPT END

done
### MAIN LOOP END
