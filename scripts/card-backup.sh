#!/usr/bin/env bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# IMPORTANT:
# Run the install-little-backup-box.sh script first
# to install the required packages and configure the system.

# Specify devices and their mount points
# and other settings
STORAGE_DEV="sdc1" # Name of the storage device
STORAGE_MOUNT_POINT="/media/storage" # Mount point of the storage device
CARD_DEV="sd[ab]1" # Name of the storage card
CARD_MOUNT_POINT="/media/card" # Mount point of the storage card
SHUTD="5" # Minutes to wait before shutdown due to inactivity

. /home/pi/little-backup-box/scripts/gpio
. /home/pi/little-backup-box/scripts/blink


gpio mode 5 out
gpio mode 6 out
gpio mode 13 out
gpio mode 19 out
gpio mode 26 out

gpio wirte 5 0
gpio write 6 0
gpio write 13 0
gpio write 19 0
gpio write 26 0


# Set the ACT LED to heartbeat
sudo sh -c "echo heartbeat > /sys/class/leds/led0/trigger"

# Shutdown after a specified period of time (in minutes) if no device is connected.
sudo shutdown -h $SHUTD "Shutdown is activated. To cancel: sudo shutdown -c"

# Wait for a USB storage device (e.g., a USB flash drive)
STORAGE=$(ls /dev/* | grep "$STORAGE_DEV" | cut -d"/" -f3)
#STORAGE=$(lsblk -x SIZE | grep sd[a-z]1  | awk '{print $1}' | sort | head -n 1)
while [ -z "${STORAGE}" ]
  do
  sleep 1
  STORAGE=$(ls /dev/* | grep "$STORAGE_DEV" | cut -d"/" -f3)
done

# When the USB storage device is detected, mount it
mount /dev/"$STORAGE_DEV" "$STORAGE_MOUNT_POINT"

# Cancel shutdown
sudo shutdown -c

# Set the ACT LED to blink at 1000ms to indicate that the storage device has been mounted
sudo sh -c "echo timer > /sys/class/leds/led0/trigger"
sudo sh -c "echo 1000 > /sys/class/leds/led0/delay_on"

# Wait for a card reader or a camera
# takes first device found
CARD_READER=($(ls /dev/* | grep "$CARD_DEV" | cut -d"/" -f3))
until [ ! -z "${CARD_READER[0]}" ]
  do
  sleep 1
  CARD_READER=($(ls /dev/* | grep "$CARD_DEV" | cut -d"/" -f3))
done

# If the card reader is detected, mount it and obtain its UUID
if [ ! -z "${CARD_READER[0]}" ]; then
  mount /dev"/${CARD_READER[0]}" "$CARD_MOUNT_POINT"

  CARD_COUNT=$(find $CARD_MOUNT_POINT/ -type f | wc -l)
  # # Set the ACT LED to blink at 500ms to indicate that the card has been mounted
  sudo sh -c "echo 500 > /sys/class/leds/led0/delay_on"

  # Create  a .id random identifier file if doesn't exist
  cd "$CARD_MOUNT_POINT"
  if [ ! -f *.id ]; then
    random=$(echo $RANDOM)
    touch $(date -d "today" +"%Y%m%d%H%M")-$random.id
  fi
  ID_FILE=$(ls *.id)
  ID="${ID_FILE%.*}"
  cd

  # Set the backup path
  BACKUP_PATH="$STORAGE_MOUNT_POINT"/"$ID"
  STORAGE_COUNT=$(find $BACKUP_PATH/ -type f | wc -l)
  # Perform backup using rsync
  rsync -avh --info=progress2 --exclude "*.id" "$CARD_MOUNT_POINT"/ "$BACKUP_PATH" &
  pid=$!

  COUNTER=0
  while kill -0 $pid 2> /dev/null
    do
    STORAGE_COUNT=$(find $BACKUP_PATH/ -type f | wc -l)
    PERCENT=$(expr 100 \* $STORAGE_COUNT / $CARD_COUNT)
    sudo sh -c "echo $PERCENT"
    #IF STATEMENTS HERE FOR LEDS
    if [ $PERCENT -lt 19 ]; then
      if [ "$COUNTER" -eq 0 ]; then
        blink 26 0.25 &
        blink_pid1=$!
        COUNTER=$((COUNTER+1))
      fi

    elif [ $PERCENT -gt 20 ] && [ $PERCENT -lt 39 ]; then
      kill $blink_pid1 2> /dev/null
      gpio write 26 1
      if [ "$COUNTER" -eq 1 ]; then
        blink 19 0.25 &
        blink_pid2=$!
        COUNTER=$((COUNTER+1))
      fi

    elif [ $PERCENT -gt 40 ] && [ $PERCENT -lt 59 ]; then
      kill $blink_pid2 2> /dev/null
      gpio write 26 1
      gpio write 19 1
      if [ "$COUNTER" -eq 2 ]; then
        blink 13 0.25 &
        blink_pid3=$!
        COUNTER=$((COUNTER+1))
      fi
    elif [ $PERCENT -gt 60 ] && [ $PERCENT -lt 79 ]; then
      kill $blink_pid3 2> /dev/null
      gpio write 26 1
      gpio write 19 1
      gpio write 13 1
      if [ "$COUNTER" -eq 3 ]; then
        blink 6 0.25 &
        blink_pid4=$!
        COUNTER=$((COUNTER+1))
      fi
    elif [ $PERCENT -gt 80 ] && [ $PERCENT -lt 100 ]; then
      kill $blink_pid4 2> /dev/null
      gpio write 26 1
      gpio write 19 1
      gpio write 13 1
      gpio write 6 1
      if [ "$COUNTER" -eq 3 ]; then
        blink 5 0.25 &
        blink_pid5=$!
        COUNTER=$((COUNTER+1))
      fi
    fi

    sleep 1
  done
  kill $blink_pid5 2> /dev/null
  gpio write 26 1
  gpio write 19 1
  gpio write 13 1
  gpio write 6 1
  gpio write 5 1

  sleep 5

  gpio clean 5
  gpio clean 6
  gpio clean 13
  gpio clean 19
  gpio clean 26
fi

# Shutdown
sync
shutdown -h now
