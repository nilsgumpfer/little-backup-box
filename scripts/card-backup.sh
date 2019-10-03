#!/usr/bin/env bash

STORAGE_DEV="sdb1" 
STORAGE_MOUNT_POINT="/media/storage" 
CARD_DEV="sda1" 
CARD_MOUNT_POINT="/media/card"


# ------------ SD Card ----------------

# Print on display
sudo python3 /home/pi/little-backup-box/scripts/display.py -t "   Insert SD card"

# Wait for SD card
CARD=$(ls /dev/sd* | grep "$CARD_DEV" | cut -d"/" -f3)
while [ -z "${CARD}" ]
  do
  sleep 0.1
  CARD=$(ls /dev/sd* | grep "$CARD_DEV" | cut -d"/" -f3)
done

# When the SD card is detected, mount it
mount /dev/"$CARD_DEV" "$CARD_MOUNT_POINT"

# ------------ SD Card ----------------


# ------------ USB Stick ----------------

# Print on display
sudo python3 /home/pi/little-backup-box/scripts/display.py -t "  Insert USB device"

# Wait for a USB storage device (e.g., a USB flash drive)
STORAGE=$(ls /dev/sd* | grep "$STORAGE_DEV" | cut -d"/" -f3)
while [ -z "${STORAGE}" ]
  do
  sleep 0.1
  STORAGE=$(ls /dev/sd* | grep "$STORAGE_DEV" | cut -d"/" -f3)
done

# When the USB storage device is detected, mount it
mount /dev/"$STORAGE_DEV" "$STORAGE_MOUNT_POINT"

# ------------ USB Stick ----------------


# ------------ Preparations -------------

# Create  an .id random identifier file if doesn't exist
cd "$CARD_MOUNT_POINT"
if [ ! -f *.id ]; then
  random=$(echo $RANDOM)
  touch $random.id
fi
ID_FILE=$(ls *.id)
ID="${ID_FILE%.*}"
cd

# Set the backup path
BACKUP_PATH="$STORAGE_MOUNT_POINT"/"cardbackup_$ID"

# Count files
CARD_COUNT=$(find $CARD_MOUNT_POINT/ -type f | wc -l)
STORAGE_COUNT_INIT=$(find $BACKUP_PATH/ -type f | wc -l)

if [ -z "${STORAGE_COUNT_INIT}" ]; then
  STORAGE_COUNT_INIT=0
fi

TO_TRANSFER=$(expr $CARD_COUNT - $STORAGE_COUNT_INIT - 1)

# ------------ Preparations -------------


# ------------ Backup -------------------

# Perform backup using rsync
rsync -avh --info=progress2 --exclude "*.id" "$CARD_MOUNT_POINT"/ "$BACKUP_PATH" &
pid=$!

while kill -0 $pid 2> /dev/null
  do
  STORAGE_COUNT_CURR=$(find $BACKUP_PATH/ -type f | wc -l)
  TRANSFERRED=$(expr $STORAGE_COUNT_CURR - $STORAGE_COUNT_INIT)
  PERCENT=$(expr 100 \* $TRANSFERRED / $TO_TRANSFER)

  # Print on display
  sudo python3 /home/pi/little-backup-box/scripts/display.py -t "Progress:  $PERCENT %" -t "Files:  $TRANSFERRED / $TO_TRANSFER"
  
  sleep 0.1
done

# ------------ Backup -------------------


# ------------ Finish -------------------

# Print on display
sudo python3 /home/pi/little-backup-box/scripts/display.py -t "      Finished" -t "   Shutting down"

# Shutdown
sync
shutdown -h now

# ------------ Finish -------------------