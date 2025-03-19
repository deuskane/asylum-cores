#!/bin/bash

#-----------------------------------------------------------------------------
# Title      : Dump script
# Project    : Asylum
#-----------------------------------------------------------------------------
# File       : dump.sh
# Author     : mrosiere
#-----------------------------------------------------------------------------
# Description: 
#-----------------------------------------------------------------------------
# Copyright (c) 2021
#-----------------------------------------------------------------------------
# Revisions  :
# Date        Version  Author   Description
# 2021-10-28  1.0      mrosiere Created
# 2021-11-23  1.1      mrosiere Use getops
# 2025-02-18  1.2      mrosiere Split dump and import scripts
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# dump_main
#-----------------------------------------------------------------------------
# 
#-----------------------------------------------------------------------------
function dump_main()
{
    src_dir=.
    file=${src_dir}/README.md

    rm -f ${file}
    
    vendor_prev=""
    library_prev=""
    
    for core in `find ${src_dir} -iname "*.core" | sort -V`;
    do
	echo ${core}
	
        fullname=$(grep name ${core}|head -n1)
        description=$(grep description ${core}|head -n1|sed 's/^[^:]*://g')
        
        vendor=$( echo ${fullname}|cut -d':' -f2| tr -cd [:graph:])
        library=$(echo ${fullname}|cut -d':' -f3| tr -cd [:graph:])
        name=$(   echo ${fullname}|cut -d':' -f4| tr -cd [:graph:])
        version=$(echo ${fullname}|cut -d':' -f5| tr -cd [:graph:])

	if test "${vendor}" != "${vendor_prev}";
	then
	    printf "# ${vendor}\n" >> ${file}
	    library_prev=""
	fi;

	if test "${library}" != "${library_prev}";
	then
	    printf "## ${library}\n" >> ${file}

	    printf "| %-20s | %-20s | %-20s | %-100s | Description |\n" "Vendor" "Library" "Name" "Version" >> ${file}
	    printf "| %-20s | %-20s | %-20s | %-100s | --- |\n"         "---"     "---"    "---"  "---"     >> ${file}

	fi;

	printf "| %-20s | %-20s | %-20s | %-100s | %s|\n" "${vendor}" "${library}" "${name}" "[${version}](${core/${src_dir}\//})" "${description}">> ${file}
	
	vendor_prev=${vendor}
	library_prev=${library}

    done
}

dump_main $*








