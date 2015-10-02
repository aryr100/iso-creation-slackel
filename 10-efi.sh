#!/bin/sh
#
# This script get the EFI files from slackware and adapts them
# to Salix.
#
# You will first need to install curlftpfs to use it.

if [ "$UID" -eq "0" ]; then
	echo "Don't run this script as root"
	exit 1
fi

if [ ! -x /usr/bin/curlftpfs ]; then
	echo "curlftpfs is missing"
	exit 1
fi

set -e

if [ ! -f ARCH ]; then
	echo "No ARCH file."
	exit 1
else
	arch=`cat ARCH`
fi

if [ ! -f VERSION ]; then
	echo "No VERSION file."
	exit 1
else
	#ver=`cat VERSION`
	ver='current'
fi

if [ ! -d isolinux/x86_64 ]; then
	echo "I can't find the isolinux files."
	exit 1
fi

CWD=`pwd`

if [[ "$arch" != "x86_64" ]]; then
	echo "This only works for x86_64."
	exit 1
fi

# clean up previous files
rm -rf EFI

# create the mountpoint for the ftpfs
mkdir ftp
FTP="$CWD/ftp"

# mount the slackware.org.uk ftp server with curlftpfs
echo "Mounting ftp repository..."
#curlftpfs ftp://ftp.slackware.org.uk ftp
#curlftpfs ftp://ftp.ntua.gr/pub/linux/ ftp
curlftpfs ftp://ftp.osuosl.org/pub/slackware/slackware64-$ver ftp

# get the slack EFI files
echo "Getting the slackware EFI files..."
#cp -r $FTP/slackware/slackware64-$ver/EFI ./
#cp $FTP/slackware/slackware64-$ver/isolinux/efiboot.img isolinux/x86_64/
cp -r $FTP/EFI ./
cp $FTP/isolinux/efiboot.img isolinux/x86_64/

# Slackware->Salix
#sed -i "s/Slackware/Salix/g" EFI/BOOT/grub.cfg
# Slackware->Slackel
sed -i "s/Slackware/Slackel/g" EFI/BOOT/grub.cfg

# unmount the ftpfs and remove the mountpoint
echo "Unmounting ftp repository..."
fusermount -u $FTP
rmdir $FTP

echo "DONE!"
set +e
