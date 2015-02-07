#!/bin/bash

DISTRO_LIST=(arch NOOBS NOOBS_lite pidora raspbian raspbmc riscos)
PI_DOWNLOADS=http://www.raspberrypi.org/downloads/
WORK_DIR=${HOME}/piconfig
SHA_CACHE=${WORK_DIR}/distro-sha.txt

function checkRoot() {
  [ ${USER} != root ] && echo "Must be root to run this script" && exit 1
}

function chooseDistro() {
  while [[ ! ${OPTION} =~ [1-8] ]]
  do
    clear
    echo "Choose a distro:"
    echo
    echo "1) arch           -      Arch Linux"
    echo "2) NOOBS          -      Offline and network install"
    echo "3) NOOBS Lite     -      Network install only"
    echo "4) pidora         -      Fedora Remix"
    echo "5) raspbian       -      Debian Wheezy"
    echo "6) raspbmc        -      XBMC Media Centre"
    echo "7) riscos         -      Non-Linux distribution"
    echo "8) Exit           -      Exits this script"
    echo
    echo -n "Enter distro number: "
    read OPTION
  done

  [ ${OPTION} -eq 8 ] && exit 0

  SELECTED_DISTRO=${DISTRO_LIST[$((${OPTION} -1))]}
}

function setup() {
  [ ! -d ${WORK_DIR} ] && mkdir ${WORK_DIR} && chown ${SUDO_USER}:${SUDO_USER} ${WORK_DIR}

  OS_DOWNLOAD_URL=http://downloads.raspberrypi.org/${SELECTED_DISTRO}_latest
  OS_ZIP_FILE=${WORK_DIR}/${SELECTED_DISTRO}_latest.zip
  OS_IMG_FILE=${WORK_DIR}/${SELECTED_DISTRO}_latest.img
}

function fetchShaHashes() {
  DISTRO_SHA_HASHES=$(curl -s ${PI_DOWNLOADS} | grep -o -E -e "[0-9a-f]{40}")

  su - ${SUDO_USER} -c "> ${WORK_DIR}/distro-sha.txt"

  for SHA in ${DISTRO_SHA_HASHES}
  do
    if ! grep ${SHA} ${WORK_DIR}/distro-sha.txt > /dev/null
    then
      su - ${SUDO_USER} -c "echo ${SHA} >> ${WORK_DIR}/distro-sha.txt"
    fi
  done
}

function validateDistroSha() {
  ACTUAL_SHA=$(sha1sum ${OS_ZIP_FILE} | cut -f1 -d' ')

  if [ -f ${SHA_CACHE} ]
  then
    grep ${ACTUAL_SHA} ${SHA_CACHE} > /dev/null && return 0
  fi

  fetchShaHashes

  for DISTRO_SHA_HASH in ${DISTRO_SHA_HASHES}
  do
    [ "${DISTRO_SHA_HASH}" == "${ACTUAL_SHA}" ] && return 0
  done

  return 1
}

function downloadDistro() {
  if [ -f ${OS_ZIP_FILE} ] && validateDistroSha
  then
    echo
    echo "Using cached distro image ${OS_ZIP_FILE}"
    echo
  else
    echo
    echo "Downloading distro from ${OS_DOWNLOAD_URL}"
    echo
    su - ${SUDO_USER} -c "curl --location ${OS_DOWNLOAD_URL} > ${OS_ZIP_FILE}"
  fi
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

  if [ -z "${SD_CARD_DEVICE}" ] || [ ! -b ${SD_CARD_DEVICE} ]
  then
    echo "Device ${SD_CARD_DEVICE} is not valid"
    exit 1
  fi
}

function unmountSDCard() {
  for MOUNT_POINT in $(df | grep ${SD_CARD_DEVICE} | awk '{print $6}')
  do
    echo "Unmounting ${MOUNT_POINT}"
    umount ${MOUNT_POINT}
    [ $? -ne 0 ] && echo "Unable to unmount ${MOUNT_POINT}" && exit 1
  done
}

function unzipImage() {
  echo "Unzipping ${OS_ZIP_FILE}"
  su - ${SUDO_USER} -c "unzip -p ${OS_ZIP_FILE} > ${OS_IMG_FILE}"
}

function writeImage() {
  if validateDistroSha
  then
    unzipImage
    unmountSDCard

    echo "Creating file system on ${SD_CARD_DEVICE}"
    mkdosfs -F 32 -I ${SD_CARD_DEVICE} > /dev/null

    if [ $? -eq 0 ]
    then
      echo "Writing image ${OS_IMG_FILE} to ${SD_CARD_DEVICE}"
      dd bs=4M if=${OS_IMG_FILE} of=${SD_CARD_DEVICE}
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
downloadDistro
getSDCardDevice
writeImage
