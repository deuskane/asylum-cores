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
	
        fullname=$(grep ^name ${core}|head -n1)
        description=$(grep description ${core}|head -n1|sed 's/^[^:]*://g')
        
        vendor=$( echo ${fullname}|cut -d':' -f2| tr -cd [:graph:])
        library=$(echo ${fullname}|cut -d':' -f3| tr -cd [:graph:])
        name=$(   echo ${fullname}|cut -d':' -f4| tr -cd [:graph:])
        version=$(echo ${fullname}|cut -d':' -f5| tr -cd [:graph:])

	# Variables pour stocker les informations
	provider_name=""
	provider_user=""
	provider_repo=""
	provider_version=""
	inside_provider=false

	# Lecture du fichier ligne par ligne
	while IFS= read -r line; do
	    if [[ "$line" == "#<PROVIDER_BEGIN>" ]]; then
		inside_provider=true
	    elif [[ "$line" == "#<PROVIDER_END>" ]]; then
		inside_provider=false
	    elif $inside_provider; then
		if   [[ "$line" =~ " name" ]]; then
		    provider_name=$(echo "$line" | awk -F ': ' '{print $2}')
		elif [[ "$line" =~ " user" ]]; then
		    provider_user=$(echo "$line" | awk -F ': ' '{print $2}')
		elif [[ "$line" =~ " repo" ]]; then
		    provider_repo=$(echo "$line" | awk -F ': ' '{print $2}')
		elif [[ "$line" =~ " version" ]]; then
		    provider_version=$(echo "$line" | awk -F ': ' '{print $2}')
		fi
	    fi
	done < "${core}"	
	
	URL="https://${provider_name}.com/${provider_user}/${provider_repo}/tree/${provider_version}"

	#echo ${URL}
	
	if test "${vendor}" != "${vendor_prev}";
	then
	    printf "# ${vendor}\n" >> ${file}
	    library_prev=""
	fi;


	
	if test "${library}" != "${library_prev}";
	then
	    printf "## ${library}\n" >> ${file}

	    printf "| %-20s | %-20s | %-20s | %-100s | %-20s | Description |\n" "Vendor" "Library" "Name" "URL" "Version" >> ${file}
	    printf "| %-20s | %-20s | %-20s | %-100s | %-20s | --- |\n"         "---"     "---"    "---"  "---"  "---"     >> ${file}

	fi;

	printf "| %-20s | %-20s | %-20s | %-100s | %s|\n" "${vendor}" "${library}" "${name}" "[${version}](${core/${src_dir}\//})" "[url](${URL})" "${description}">> ${file}
	
	vendor_prev=${vendor}
	library_prev=${library}

    done
}

dump_main $*








