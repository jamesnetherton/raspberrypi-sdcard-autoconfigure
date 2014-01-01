# Automated Raspberry Pi SD Card Setup
This project automates the setup of an SD card for the Raspberry Pi. It enables a target operating system to be selected and then downloaded, extracted and loaded onto an SD card.

## Prerequisites
1. Linux - This project has only been tested against Debian variants thus far 
2. An SD card inserted into a card reader which is connected to your computer
3. A working internet connection
4. curl
5. Enough disk space within your home directory partition to download and extract the OS images. 5GB will be sufficient.

## Overview 
The script does the following:

1. Prompts you to choose a Raspberry Pi OS flavour and enter the location of your SD card device
2. The script retrieves a set of expected OS SHA-1 hashes from respberrypi.org together with the latest archive of the OS that was selected
3. The OS archive is downloaded into $HOME/piconfig. The script checks on each run to see whether the latest image for the selected OS exists within the $HOME/piconfig. If the file does not exist then it is downloaded
4. The selected SD card device is formatted 
5. The OS archive is unzipped and the resulting OS image file is written to the SD card 

## Usage
To execute the script:

	chmod +x ./configuresdcard.sh
	sudo ./configuresdcard.sh

When prompted:
1. Choose a distro from the list that is presented to you
2. Enter the device location that corresponds to your SD card reader (running df -h may help to identify this)

**Make sure to double check that you have entered the correct device. If you get it wrong you'll end up unintentionally deleting a disk partition which may end up being your primary Linux partition!**

When the script has completed, you should have a usable SD card that can be inserted into the Raspberry Pi and booted.
