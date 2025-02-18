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
    
    company_prev=""
    type_prev=""
    
    for core in `find ${src_dir} -iname "*.core" | sort -V`;
    do
	echo ${core}
	
        fullname=$(grep name ${core}|head -n1)
        description=$(grep description ${core}|head -n1|sed 's/^[^:]*://g')
        
        company=$(echo ${fullname}|cut -d':' -f2| tr -cd [:graph:])
        type=$(   echo ${fullname}|cut -d':' -f3| tr -cd [:graph:])
        name=$(   echo ${fullname}|cut -d':' -f4| tr -cd [:graph:])
        version=$(echo ${fullname}|cut -d':' -f5| tr -cd [:graph:])

	if test "${company}" != "${company_prev}";
	then
	    printf "# ${company}\n" >> ${file}
	    type_prev=""
	fi;

	if test "${type}" != "${type_prev}";
	then
	    printf "## ${type}\n" >> ${file}

	    printf "| %-20s | %-20s | %-20s | %-100s | Description |\n" "Company" "Type" "Name" "Version" >> ${file}
	    printf "| %-20s | %-20s | %-20s | %-100s | --- |\n"         "---"     "---"  "---"  "---"     >> ${file}

	fi;

	printf "| %-20s | %-20s | %-20s | %-100s | %s|\n" "${company}" "${type}" "${name}" "[${version}](${core/${src_dir}\//})" "${description}">> ${file}
	
	company_prev=${company}
	type_prev=${type}

    done
}

dump_main $*








