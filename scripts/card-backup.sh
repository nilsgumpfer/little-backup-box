#!/usr/bin/env bash

# IMPORTANT:
# Run the install-little-backup-box.sh script first
# to install the required packages and configure the system.

# Specify devices and their their mount points
# as well as other settings
STORAGE_DEV="sda1" # Name of the storage device
STORAGE_MOUNT_POINT="/media/storage" # Mount point of the storage device
CARD_DEV="sdb1" # Name of the storage card
CARD_MOUNT_POINT="/media/card" # Mount point of the storage card

# Print on display
sudo python3 /home/pi/little-backup-box/scripts/display.py -t "   Insert SD card"

# Wait for SD card
CARD_READER=($(ls /dev/sd* | grep "$CARD_DEV" | cut -d"/" -f3))
until [ ! -z "${CARD_READER[0]}" ]
  do
  sleep 0.1
  CARD_READER=($(ls /dev/sd* | grep "$CARD_DEV" | cut -d"/" -f3))
done

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

# If card was detected, mount it and obtain its UUID
if [ ! -z "${CARD_READER[0]}" ]; then
  mount /dev"/${CARD_READER[0]}" "$CARD_MOUNT_POINT"

  CARD_COUNT=$(find $CARD_MOUNT_POINT/ -type f | wc -l)

  # Create  an .id random identifier file if doesn't exist
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
  #TOTRANSFER=$(expr 100 \* $STORAGE_COUNT / $CARD_COUNT)

  # Perform backup using rsync
  rsync -avh --info=progress2 --exclude "*.id" "$CARD_MOUNT_POINT"/ "$BACKUP_PATH" &
  pid=$!

  while kill -0 $pid 2> /dev/null
    do
    STORAGE_COUNT=$(find $BACKUP_PATH/ -type f | wc -l)
    PERCENT=$(expr 100 \* $STORAGE_COUNT / $CARD_COUNT)

    sudo python3 /home/pi/little-backup-box/scripts/display.py -t "Progress:  $PERCENT %" -t "Files:  $STORAGE_COUNT / $CARD_COUNT"
    
    sleep 0.1
  done
fi

sudo python3 /home/pi/little-backup-box/scripts/display.py -t "      Finished" -t "   Shutting down"

# Shutdown
sync
shutdown -h now
