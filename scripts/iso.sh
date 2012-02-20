#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: iso.sh,v 1.3 2008/11/08 21:23:31 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

FREESBIE_LABEL=${FREESBIE_LABEL:-"FreeSBIE"}

echo ">>> Building bootable ISO image for ${ARCH}"

# This part was taken from the mkisoimages.sh scripts under
# /usr/src/release/${ARCH}/
set +e
type mkisofs 2>&1 | grep " is " >/dev/null
if [ $? -ne 0 ]; then
    echo The cdrtools port is not installed.  Trying to get it now.
    if [ -f /usr/ports/sysutils/cdrtools/Makefile ]; then
	cd /usr/ports/sysutils/cdrtools && make install BATCH=yes && make clean
    else
	if ! pkg_add -r cdrtools; then
	    echo "Could not get it via pkg_add - please go install this"
	    echo "from the ports collection and run this script again."
	    exit 2
	fi
    fi
fi
set -e

echo ">>> Saving mtree structure..."
mtree -Pcp ${CLONEDIR} | bzip2 -9 > root.dist.bz2
mkdir -p ${CLONEDIR}/dist
mv root.dist.bz2 ${CLONEDIR}/dist/

echo "/dev/iso9660/${FREESBIE_LABEL} / cd9660 ro 0 0" > ${CLONEDIR}/etc/fstab

cd ${CLONEDIR}

# Detect if mkisofs support -L or -posix-L
if mkisofs --help 2>&1 | grep -q -- -posix-L; then
	LOPT="-posix-L"
else
	LOPT="-L"
fi

echo ">>> Running mkisofs..."


echo ">>> FreeSBIe2 is running the command: cd ${CLONEDIR} ; mkisofs -b boot/cdboot -no-emul-boot -J -r -ldots -l ${LOPT} -V ${FREESBIE_LABEL} -p FreeSBIE -o $ISOPATH ." > /tmp/freesbie_cd_builder.txt

mkisofs -b boot/cdboot -no-emul-boot -J -r -ldots -l ${LOPT} -V ${FREESBIE_LABEL} -p pfSense -o $ISOPATH .

echo "ISO created:"

ls -lh ${ISOPATH}

cd ${LOCALDIR}
