#!/bin/sh
#
# This script gets a slackware initrd.img file from a slackware
# repository and converts it to a slackel initrd.img file.
#
# You really shouldn't build an initrd yourself if you're
# making a custom iso. Use the initrd files found in a
# Salix iso instead.
#
# This script assumes that in a 32bit system, you're running the smp
# kernel and that you at least have the non-smp kernel-modules package
# installed.
#
# You need to be running a stock slackware kernel.

set -e

CWD=`pwd`
SCRIPTSDIR=$CWD/initrd-scripts

if [ "$UID" != "0" ]; then
	echo "You need to be root to run this"
	exit 1
fi

if [ ! -f USER ]; then
	echo "No USER file."
	exit 1
fi
user=`cat USER`

if [ ! -f VERSION ]; then
	echo "No VERSION file."
	exit 1
else
	VER=`cat VERSION`
	VERSLACKWARE='current'
fi

if [ -z "$arch" ]; then
	case "$( uname -m )" in
		i?86) arch=i486 ;;
		*) arch=$( uname -m ) ;;
	esac
fi

MSG="This script gets a slackware initrd.img file from a slackware\n\
repository and converts it to a slackel initrd.img file.\n\
\n\
You really shouldn't build an initrd yourself if you're\n\
making a custom iso. Use the initrd files found in a\n\
Salix iso instead.\n\
\n\
When you get the initrd files from a slackel iso, put them in an\n\
initrd/i486 or initrd/x86_64 directory, according to your\n\
architecture.\n\
\n\
This script assumes that in a 32bit system, you're running the smp\n\
kernel and that you at least have the non-smp kernel-modules package\n\
installed.\n\
\n\
You need to be running a stock slackware kernel.\n\
\n\
You also need to be running the architecture for which you are\n\
creating the initrd for. The architecture you are running now\n\
is ${arch}.\n\
\n\
ARE YOU SURE YOU KNOW WHAT YOU'RE DOING?"

dialog --title "Are you sure you want to do this?" \
	--defaultno \
	--yesno "$MSG" 0 0
retval=$?
if [ $retval -eq 1 ] || [ $retval -eq 255 ]; then
	exit 0
fi

unset LIBDIRSUFFIX
if [[ "$arch" == "x86_64" ]]; then
	export LIBDIRSUFFIX="64"
fi

#$VER=14.1

REPO=http://slackware.org.uk
SLACKREPO=$REPO/slackware/slackware${LIBDIRSUFFIX}-$VERSLACKWARE
SLACK2REPO=$SLACKREPO/slackware${LIBDIRSUFFIX}
SALIXREPO=$REPO/salix/$arch/$VER/

mkdir -p initrd/$arch
rm -rf initrd/$arch/*initrd*.img

# get the slack initrd
# use wget instead of ftp, less error prone
echo "Getting the slackware initrd..."
wget -q $SLACKREPO/isolinux/initrd.img -O initrd/$arch/slack-initrd.img

# unpack slack initrd
echo "Unpacking slackware initrd..."
rm -rf /boot/initrd-tree
mkdir /boot/initrd-tree
cd /boot/initrd-tree
gzip -dc < $CWD/initrd/$arch/slack-initrd.img | cpio -i
# not needed anymore
cd $CWD
rm initrd/$arch/slack-initrd.img

# replace rc.d scripts
echo "Replacing rc.d scripts..."
rm /boot/initrd-tree/etc/rc.d/*
cp $SCRIPTSDIR/etc-rc.d/* /boot/initrd-tree/etc/rc.d/
# replace setup scripts
echo "Replacing setup scripts..."
rm /boot/initrd-tree/usr/lib/setup/*
cp $SCRIPTSDIR/usr-lib-setup/* /boot/initrd-tree/usr/lib/setup/

# download and install required packages
rm -f slack.md5 salix.md5
echo "Downloading slack CHECKSUMS.md5 file"
wget -q $SLACK2REPO/CHECKSUMS.md5 -O slack.md5
echo "Downloading slackel CHECKSUMS.md5 file"
wget -q $SALIXREPO/CHECKSUMS.md5 -O salix.md5

echo "Downloading spkg..."
rm -f spkg-*.txz
LOC=`grep "\/spkg-.*-.*-.*\.tgz$" salix.md5 | sed "s|\(.*\)  \./\(.*\)|\2|"`
wget -q $SALIXREPO/$LOC
echo "Installing spkg..."
spkg -qq --root=/boot/initrd-tree/ -i spkg-*.tgz
rm spkg-*.tgz

echo "Downloading xz..."
rm -f xz-*.tgz
LOC=`grep "\/xz-.*-.*-.*\.tgz$" slack.md5 | sed "s|\(.*\)  \./\(.*\)|\2|"`
wget -q $SLACK2REPO/$LOC
echo "Installing xz..."
spkg -qq --root=/boot/initrd-tree/ -i xz-*.tgz
rm xz-*.tgz

install_nfsutils() {
echo "Downloading nfsutils..."
rm -f nfs-utils-*.txz
LOC=`grep "\/nfs-utils-.*-.*-.*\.txz$" slack.md5 | sed "s|\(.*\)  \./\(.*\)|\2|"`
wget -q $SLACK2REPO/$LOC
echo "Installing showmount binary from nfsutils..."
tar xf nfs-utils-*.txz -C /boot/initrd-tree usr/sbin/showmount
rm nfs-utils-*.txz
}
#install_nfsutils

install_fuse() {
echo "Downloading fuse..."
rm -f fuse-*.txz
LOC=`grep "\/fuse-.*-.*-.*\.txz$" slack.md5 | sed "s|\(.*\)  \./\(.*\)|\2|"`
wget -q $SLACK2REPO/$LOC
echo "Installing fuse..."
spkg -qq --root=/boot/initrd-tree/ -i fuse-*.txz
rm fuse-*.txz
echo "Downloading kernel modules"
MODULES=`grep "\/kernel-modules-.*-.*-.*\.txz$" slack.md5 | sed "s|\(.*\)  \./\(.*\)|\2|"`
for LOC in $MODULES; do
	wget -q $SLACK2REPO/$LOC
done
echo "Installing fuse.ko kernel modules..."
for i in `ls kernel-modules-*.txz`; do
	tar xf $i -C /boot/initrd-tree --wildcards "*/fuse.ko"
done
rm kernel-modules-*.txz
}
#install_fuse

install_httpfs2() {
echo "Downloading httpfs2..."
rm -f httpfs2-*.txz
LOC=`grep "\/httpfs2-.*-.*-.*\.txz$" salix.md5 | sed "s|\(.*\)  \./\(.*\)|\2|"`
wget -q $SALIXREPO/$LOC
echo "Installing httpfs2..."
spkg -qq --root=/boot/initrd-tree/ -i httpfs2-*.txz
rm httpfs2-*.txz
}
#install_httpfs2

install_cyrus_sasl() {
echo "Downloading cyrus-sasl..."
rm -f cyrus-sasl-*.txz
LOC=`grep "\/cyrus-sasl-.*-.*-.*\.txz$" slack.md5 | sed "s|\(.*\)  \./\(.*\)|\2|"`
wget -q $SLACK2REPO/$LOC
echo "Installing cyrus-sasl..."
spkg -qq --root=/boot/initrd-tree/ -i cyrus-sasl-*.txz
rm cyrus-sasl-*.txz
}
#install_cyrus_sasl

install_samba() {
echo "Downloading samba..."
rm -f samba-*.txz
LOC=`grep "\/samba-.*-.*-.*\.txz$" slack.md5 | sed "s|\(.*\)  \./\(.*\)|\2|"`
wget -q $SLACK2REPO/$LOC
echo "Installing smbclient binary from samba..."
tar xf samba-*.txz -C /boot/initrd-tree --wildcards \
  usr/bin/smbclient \
  usr/lib${LIBDIRSUFFIX}/*.dat \
  usr/lib${LIBDIRSUFFIX}/charset/*
install -d /boot/initrd-tree/etc/samba
touch /boot/initrd-tree/etc/samba/smb.conf
rm samba-*.txz
}
#install_samba

echo "Tweaking config files..."
# network logon message
cat << EOF > /boot/initrd-tree/etc/motd.net

Welcome to Slackel${LIBDIRSUFFIX} $VER

Please run '. /etc/profile' to initialise the environment.

EOF
# change the hostname
sed "s/slackware/slackel${LIBDIRSUFFIX}/g" -i /boot/initrd-tree/etc/HOSTNAME
sed "/^127.0.0.1/s|slackware|slackel${LIBDIRSUFFIX}|g" -i /boot/initrd-tree/etc/hosts

# remove not needed dirs
echo "Removing unnecessary stuff..."
rm -rf /boot/initrd-tree/usr/{doc,include,man,src}
rm -rf /boot/initrd-tree/usr/share/locale
rm -rf /boot/initrd-tree/usr/src
rm -rf /boot/initrd-tree/var/log/packages
# remove cyrus-sasl stuff
rm -f /boot/initrd-tree/usr/sbin/{pluginviewer,saslauthd,sasldblistusers2,saslpasswd2,testsaslauthd}
rm -f /boot/initrd-tree/etc/rc.d/rc.saslauthd
rm -rf /boot/initrd-tree/usr/lib${LIBDIRSUFFIX}/sasl*/

# in i486 the initrd is >32MB, so we need to split it in two
if [ "$arch" == "x86_64" ] ; then
	# repack x86_64 initrd
	echo "Repacking x86_64 initrd..."
	depmod -b /boot/initrd-tree/
	rm -f /boot/initrd-tree/{wait-for-root,rootfs,rootdev,initrd-name}
	mkinitrd -o $CWD/initrd/$arch/initrd.img
else
	#
	# first create a combined initrd
	# (we're disabling this for now)
	#echo "Repacking i486 initrd (combined smp and non-smp)..."
	#depmod -b /boot/initrd-tree/ $( uname -r | sed "s/-smp//" )
	#mkinitrd -o $CWD/initrd/$arch/initrd.img
	
	#
	# then do the split ones
	#
	cp -ar /boot/initrd-tree /boot/initrd-tree-copy
	# first pack the non-smp initrd
	echo "Repacking i486 non-smp initrd..."
	rm -rf /boot/initrd-tree/lib/modules/*-smp
	depmod -b /boot/initrd-tree/ $( uname -r | sed "s/-smp//" )
	rm -f /boot/initrd-tree/{wait-for-root,rootfs,rootdev,initrd-name}
	mkinitrd -o $CWD/initrd/$arch/nosmp.img -k $( uname -r | sed "s/-smp//" )
	# then pack the smp initrd
	echo "Repacking i486 smp initrd..."
	rm -rf /boot/initrd-tree
	mv /boot/initrd-tree-copy /boot/initrd-tree
	rm -rf $( ls -d /boot/initrd-tree/lib/modules/* | grep -v smp )
	depmod -b /boot/initrd-tree/
	rm -f /boot/initrd-tree/{wait-for-root,rootfs,rootdev,initrd-name}
	mkinitrd -o $CWD/initrd/$arch/smp.img
fi

# clean up
rm -f slack.md5 salix.md5
rm -rf /boot/initrd-tree

# chown everything back
chown -R ${user}:users initrd

echo "DONE!"
set +e
