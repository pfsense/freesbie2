#!/bin/sh
#
# Copyright (c) 2005 Dario Freni
#
# See COPYING for licence terms.
#
# $FreeBSD$
# $Id: pkginstall.sh,v 1.19 2007/01/16 10:14:46 rionda Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

#$BASE_DIR/tools/builder_scripts/packages

PFSPKGFILE=/tmp/pfspackages

if [ ! -f ${PFSPKGFILE} ]; then
    return
fi

if [ "${ARCH}" != "$(uname -p)" ]; then
    echo "----------------------------------------------------------"
    echo "You can install packages only if your machine architecture"
    echo "is the same of the target architecture."
    echo "----------------------------------------------------------"
    echo "Skipping package installation."
    sleep 5
    return    
fi

WORKDIR=$(mktemp -d -t freesbie)

prepare_environment() {
	rm -r ${PFSENSEBASEDIR}/var/db/pkg
	cp -r /var/db/pkg ${PFSENSEBASEDIR}/var/db	
}

cleanup_environment() {
	rm -r ${PFSENSEBASEDIR}/var/db/pkg
	mkdir -p ${PFSENSEBASEDIR}/var/db/pkg
}

escape_pkg() {
    echo $1 | sed 's/\+/\\\+/'
}

find_origins() {
    cd ${WORKDIR}
    touch origins
    echo -n ">>> Finding origins... " >> ${LOGFILE}
    while read row; do
	if [ -z "${row}" ]; then continue; fi
	set +e
	if (echo ${row} | grep -q "^#"); then continue; fi 
	set -e

	pkg=$(echo $row | cut -d\  -f 1)

	# pkg query might fail if the listed package isn't present
	set +e
	origins=$(pkg query -x %n-%v "^$(escape_pkg ${pkg})($|-[^-]+$)")
	retval=$?
	set -e
	if [ ${retval} -eq 0 ]; then
	    # Valid origin(s) found
	    for origin in ${origins}; do
		echo ${origin} >> tmp_origins
	    done
	else
	    echo 
	    echo "Warning! Package \"${pkg}\" is listed" 
	    echo "in ${PFSPKGFILE},"
	    echo "but is not present in your system. "
	    echo "Press CTRL-C in ten seconds if you want"
	    echo "to stop now or I'll continue anyway"
	    echo " " >> ${LOGFILE}
	    echo "Warning! Package \"${pkg}\" is listed" >> ${LOGFILE}
	    echo "in ${PFSPKGFILE}," >> ${LOGFILE}
	    echo "but is not present in your system. " >> ${LOGFILE}
	    echo "Press CTRL-C in ten seconds if you want" >> ${LOGFILE}
	    echo "to stop now or I'll continue anyway" >> ${LOGFILE}
	    sleep 10
	fi
    done < ${PFSPKGFILE}
    if [ -f tmp_origins ]; then
	sort -u tmp_origins > origins
	tot=$(wc -l origins | awk '{print $1}')
	echo "${tot} found" >> ${LOGFILE}
    else
	echo "none found" >> ${LOGFILE}
    fi
}

find_deps() {
    cd ${WORKDIR}
    touch deps
    echo ">>> Finding dependencies... " >> ${LOGFILE}
    while read pkg; do
	deps=$(pkg info -qd ${pkg})
	for dep in ${deps}; do
	    echo ">>>>> Dependency ${dep} found... " >> ${LOGFILE}
	    echo ${dep} >> tmp_deps
	done      
	
	
    done < origins
    if [ -f tmp_deps ]; then
	sort -u tmp_deps > deps
	tot=$(wc -l deps | awk '{print $1}')
	echo ">>> Total: ${tot} dependencies found" >> ${LOGFILE}
    else
	echo ">>> No dependencies found" >> ${LOGFILE}
    fi
}

sort_packages() {
    cd ${WORKDIR}
    pkgfile=${WORKDIR}/packages
    presortfile=${WORKDIR}/presortpkg
    sortfile=${WORKDIR}/sortpkg
    sort -u deps origins > $pkgfile

    [ -f $sortfile ] && rm $sortfile 
    touch $sortfile

    totpkg=$(wc -l $pkgfile | awk '{print $1}')
    echo -n ">>> Sorting ${totpkg} packages by dependencies... " >> ${LOGFILE}

    touch $presortfile
    for i in $(cat $pkgfile); do
    	_REQUIREDPKG=`pkg info -rq $i`
    	echo "Found: ${_REQUIREDPKG}" >> ${LOGFILE}
    	_COUNG_DEP=`echo $_REQUIREDPKG | wc -l`
    	if [ $_COUNG_DEP -gt 0 ]; then
    	    for j in $_REQUIREDPKG; do
		if grep -q ^${j}\$ $pkgfile; then
		    echo $i $j >> $presortfile
		else
		    echo $i NULL >> $presortfile
		fi
	    done
	else
            echo $i NULL >> $presortfile
	fi
    done
    
    tsort $presortfile | grep -v '^NULL$' > $sortfile

    echo "done." >> ${LOGFILE}
}

copy_packages() {
    export PACKAGE_BUILDING=yo
    chrootpkgpath="${BASEDIR}/${WORKDIR}"
    pkgfile=${WORKDIR}/sortpkg
    pkgaddcmd="pkg -c ${BASEDIR} add -f"
    totpkg=$(wc -l $pkgfile | awk '{print $1}')
    echo ">>> Copying ${totpkg} packages" >> ${LOGFILE}
    mkdir -p ${chrootpkgpath}
    
    set +e
    while read pkg; do
	echo ">>> Running pkg create -o ${chrootpkgpath} ${pkg}" >> ${LOGFILE}
	pkg create -o ${chrootpkgpath} -f txz ${pkg} >> ${LOGFILE} 2>&1

	echo ">>> Running $pkgaddcmd ${WORKDIR}/${pkg}.txz" >> ${LOGFILE}
	$pkgaddcmd ${WORKDIR}/${pkg}.txz >> ${LOGFILE} 2>&1

	rm ${chrootpkgpath}/${pkg}.txz

    done < $pkgfile
    echo "]" >> ${LOGFILE}
    set -e
}

delete_old_packages() {
    echo ">>> Deleting previously installed packages" >> ${LOGFILE}
    ${BASEDIR} pkg -c ${BASEDIR} delete -a >> ${LOGFILE} 2>&1
}

# Deletes workdirs
purge_wd() {
    cd ${LOCALDIR}
    rm -rf ${WORKDIR} ${BASEDIR}/tmp/freesbie*
}

trap "purge_wd && exit 1" INT

echo ">>> Installing packages listed in ${PFSPKGFILE}" >> ${LOGFILE}
find_origins

if [ "$(wc -l ${WORKDIR}/origins | awk '{print $1}')" = "0" ]; then
    # Empty packages file, skip.
    return
fi

prepare_environment
find_deps
sort_packages
#delete_old_packages
copy_packages
purge_wd
cleanup_environment
