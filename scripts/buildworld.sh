#!/bin/sh
#
# pfSense specific buildworld.sh
#
# Copyright (c) 2009 Scott Ullrich
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms (HINT: BSD License)
#

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    sleep 999
    exit 1
fi

if [ -n "${NO_BUILDWORLD:-}" ]; then
    echo "+++ NO_BUILDWORLD set, skipping build" | tee -a ${LOGFILE}
    return
fi

# Set SRC_CONF variable if it's not already set.
if [ -z "${SRC_CONF:-}" ]; then
    if [ -n "${MINIMAL:-}" ]; then
		SRC_CONF=${LOCALDIR}/conf/make.conf.minimal
    else
		SRC_CONF=${LOCALDIR}/conf/make.conf
    fi
fi

# Set __MAKE_CONF variable if it's not already set.
if [ -z "${MAKE_CONF:-}" ]; then
	MAKE_CONF=""
else
	MAKE_CONF="__MAKE_CONF=$MAKE_CONF"
	echo ">>> Setting MAKE_CONF to $MAKE_CONF"
fi

cd $SRCDIR

unset EXTRA

makeargs="${MAKEOPT:-} ${MAKEJ_WORLD:-} ${MAKE_CONF} NO_CTF=yo NO_SHARE=yo NO_CLEAN=yes SRCCONF=${SRC_CONF} TARGET=${ARCH} TARGET_ARCH=${ARCH} LOADER_ZFS_SUPPORT=YES"

if [ "$ARCH" = "mips" ]; then
	echo ">>> Building includes for ${ARCH} architecture..."
	make buildincludes 2>&1 >/dev/null
	echo ">>> Installing includes for ${ARCH} architecture..."
	make installincludes 2>&1 >/dev/null
fi

echo ">>> Building world for ${ARCH} architecture..."
echo ">>> FreeSBIe2 is running the command: env $MAKE_ENV script -aq $LOGFILE make ${makeargs:-} buildworld" >> /tmp/freesbie_buildworld_cmd.txt
(env "$MAKE_ENV" script -aq $LOGFILE make ${makeargs:-} buildworld NO_CTF=yo NO_SHARE=yo NO_CLEAN=yo || print_error;) | egrep '^>>>'

cd $LOCALDIR
