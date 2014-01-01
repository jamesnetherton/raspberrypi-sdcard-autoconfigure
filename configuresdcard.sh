#!/bin/bash

PI_DOWNLOADS=http://www.raspberrypi.org/downloads
WORK_DIR=$HOME/piconfig
DISTRO_LIST=(raspbian arch raspbmc riscos pidora)

function checkRoot() {
  [ $USER != root ] && echo "Must be root to run this script" && exit 1 
}

function chooseDistro() {
  while [[ ! $DISTRO =~ [1-5] ]]
  do
    clear
    echo "Choose a distro:"
    echo 
    echo "1) raspbian"
    echo "2) arch"
    echo "3) raspbmc"
    echo "4) riscos"
    echo "5) pidora"
    echo
    echo -n "Enter distro number: "
    read DISTRO
  done

  SELECTED_DISTRO=${DISTRO_LIST[$(($DISTRO -1))]}
}

function setup() {
  [ ! -d $WORK_DIR ] && mkdir $WORK_DIR && chown $USER:$USER $WORK_DIR

  OS_DOWNLOAD_URL=http://downloads.raspberrypi.org/${SELECTED_DISTRO}_latest
  OS_ZIP_FILE=$WORK_DIR/${SELECTED_DISTRO}_latest.zip
  OS_IMG_FILE=$WORK_DIR/${SELECTED_DISTRO}_latest.img
}

function downloadDistro() {
  echo
  echo "Downloading distro from $OS_DOWNLOAD_URL"
  echo	
  curl --location $OS_DOWNLOAD_URL > $OS_ZIP_FILE
}

function fetchShaHashes() {
  DISTRO_SHA_HASHES=$(curl -s $PI_DOWNLOADS | grep -o -E -e "[0-9a-f]{40}")
}

function checkSha() {
  if [ -f $OS_ZIP_FILE ]
  then
    ACTUAL_SHA=$(sha1sum $OS_ZIP_FILE | cut -f1 -d' ')
  fi

  for DISTRO_SHA_HASH in $DISTRO_SHA_HASHES
  do
    [ "$DISTRO_SHA_HASH" == "$ACTUAL_SHA" ] && return 0
  done

  return 1
}

function getSDCardDevice() {
  echo 
  echo "Which device represents your sd card?"
  echo 
  ls /sys/block/ | awk '/^s.*/ { print "/dev/" $1}'
  echo
  echo -n "Enter device: "
  read SD_CARD_DEVICE
  echo

  if [ -z "$SD_CARD_DEVICE" ] || [ ! -b $SD_CARD_DEVICE ]
  then
    echo "Device ${SD_CARD_DEVICE} is not valid"
    exit 1
  fi
}

function unmountSDCard() {
  for MOUNT_POINT in $(df | grep $SD_CARD_DEVICE | awk '{print $6}')
  do
    echo "Unmounting ${MOUNT_POINT}"
    umount $MOUNT_POINT
    [ $? -ne 0 ] && echo "Unable to unmount ${MOUNT_POINT}" && exit 1	
  done
}

function unzipImage() {
  echo "Unzipping $OS_ZIP_FILE"
  unzip -p $OS_ZIP_FILE > $OS_IMG_FILE
}

function writeImage() {
  if checkSha
  then
    unzipImage
    unmountSDCard

    echo "Creating file system on ${SD_CARD_DEVICE}"
    mkdosfs -F 32 -I $SD_CARD_DEVICE > /dev/null

    if [ $? -eq 0 ]
    then
      echo "Writing image ${OS_IMG_FILE} to ${SD_CARD_DEVICE}"
      dd bs=4M if=$OS_IMG_FILE of=$SD_CARD_DEVICE
      [ $? -ne 0 ] && echo "Problem writing ${OS_IMG_FILE} to ${SD_CARD_DEVICE}" && exit 1
      sync	
    else
      echo "Problem creating file system on ${SD_CARD_DEVICE}"
      exit 1
    fi
  else
    echo "SHA1 ${ACTUAL_SHA} does not match expected SHA-1 hash"
    exit 1
  fi
}

checkRoot
chooseDistro
setup
fetchShaHashes

if ! checkSha
then
  downloadDistro
fi

getSDCardDevice
writeImage
