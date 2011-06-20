#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: varmfs.sh,v 1.1.1.1 2008/03/25 19:58:15 sullrich Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

TMPFILE=$(mktemp -t varmfs)

cp ${LOCALDIR}/extra/varmfs/varmfs.rc ${BASEDIR}/etc/rc.d/varmfs
chmod 555 ${BASEDIR}/etc/rc.d/varmfs

mtree -Pcp ${BASEDIR}/var > ${TMPFILE}
mv ${TMPFILE} ${BASEDIR}/etc/mtree/var.dist

chroot ${BASEDIR} pkg_info > ${BASEDIR}/pkg_info.txt
