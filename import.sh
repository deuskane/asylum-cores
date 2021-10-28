#!/bin/bash

#-----------------------------------------------------------------------------
# Title      : Import script
# Project    : Asylum
#-----------------------------------------------------------------------------
# File       : import.sh
# Author     : mrosiere
#-----------------------------------------------------------------------------
# Description: 
#-----------------------------------------------------------------------------
# Copyright (c) 2021
#-----------------------------------------------------------------------------
# Revisions  :
# Date        Version  Author   Description
# 2021-10-28  1.0      mrosiere Created
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# import_usage
#-----------------------------------------------------------------------------
# Argument 1 : script name
#-----------------------------------------------------------------------------
# Display Usage
#-----------------------------------------------------------------------------
function import_usage()
{
    echo "Usage : $0 src dst [dry_run]"
}

#-----------------------------------------------------------------------------
# import_main
#-----------------------------------------------------------------------------
# Argument 1 : Source      directory
# Argument 2 : Destination directory
# Argument 3 : dry run
#-----------------------------------------------------------------------------
# Copy core fies
#-----------------------------------------------------------------------------
function import_main()
{
    # Check parameter number
    if test $# -ne 2 -a $# -ne 3;
    then
        import_usage $0
        return;
    fi

    if test $# -eq 3;
    then
        dry_run=$3;
    else
        dry_run=0
    fi;

    src_dir=$1
    dst_dir=$2
    verbose=0

    # Check source directory
    if test ! -d "${src_dir}";
    then
        echo "[ERROR  ] Invalid directory : \"${src_dir}\"";
        import_usage $0
        return;
    fi;

    if test ! -d "${dst_dir}";
    then
        echo "[ERROR  ] Invalid directory : \"${dst_dir}\"";
        import_usage $0
        return;
    fi;

    echo "[INFO   ] Find core files"

    src_cores=`find ${src_dir} -name "*.core"`

    nb_error=0;

    declare -A core_map;

    printf "[INFO   ] %-20s | %-20s | %-20s | %-10s \n" "Company" "Type" "Name" "Version"
    for src_core in ${src_cores};
    do
        test ${verbose} -gt 0 && echo "[DEBUG  ] * ${src_core}"
        core_dir=$(dirname ${src_core})
        core=${src_core/${src_dir}\//}
        core=${core/.core/}
        fullname=$(grep name ${src_core}|head -n1)
        
        company=$(echo ${fullname}|cut -d':' -f2| tr -cd [:graph:])
        type=$(   echo ${fullname}|cut -d':' -f3| tr -cd [:graph:])
        name=$(   echo ${fullname}|cut -d':' -f4| tr -cd [:graph:])
        version=$(echo ${fullname}|cut -d':' -f5| tr -cd [:graph:])

        printf "[INFO   ] %-20s | %-20s | %-20s | %-10s -> " ${company} ${type} ${name} ${version}

        if [ ${core_map[${company}${type}${name}]+_} ];
        then
            printf "KO : Duplicate information in file ${core_map[${company}${type}${name}]}\n"
            nb_error=$((${nb_error}+1));

            continue;
        else
            core_map[${company}${type}${name}]=${src_core}
        fi
        
#       if [[ ${version} != +([0-9]).+([0-9]).+([0-9]) ]]; 
#       then
#           printf "KO : Version bad format\n"
#           nb_error=$((${nb_error}+1));
#
#           continue;
#       fi

        version=v${version//./_}
        dst_core=${dst_dir}/${company}/${type}/${name}/`basename ${core} .core`_${version}.core
       #dst_core=${dst_dir}/${core}_${version}.core
        
        if [[ -f ${dst_core} ]];
        then
            printf "KO : Existing destination core\n"
            nb_error=$((${nb_error}+1));

            continue;
        fi

        git_url=$(cd ${core_dir} && git config --get remote.origin.url)
        
        if [[ -z ${git_url} ]];
        then
            printf "KO : Can't get git url\n"
            nb_error=$((${nb_error}+1));

            continue;
        fi
            

        git_version=$(cd ${core_dir} && git rev-parse HEAD)
        if [[ -z ${git_version} ]];
        then
            printf "KO : Can't get git id\n"
            nb_error=$((${nb_error}+1));

            continue;
        fi

        printf "OK : '%s'\n" ${dst_core}

        if [[ ${dry_run} -eq 0 ]];
        then
            mkdir -p $(dirname ${dst_core})

            cp ${src_core} ${dst_core}

            (cd ${core_dir} && git tag -a ${version} -m "Tag ${version}")


            echo ""                                      >> ${dst_core}
            echo "# Next lines is a pragma, don't modify">> ${dst_core}
            echo "#<PROVIDER_BEGIN>"                     >> ${dst_core}
            echo "provider  :"                           >> ${dst_core}
            echo "  name    : git"                       >> ${dst_core}
            echo "  repo    : ${git_url}"                >> ${dst_core}
            echo " #version : ${version}"                >> ${dst_core}
            echo "  version : ${git_version}"            >> ${dst_core}
            echo "#<PROVIDER_END>"                       >> ${dst_core}
        fi
    done

    if [[ ${nb_error} -gt 0 ]];
    then
        echo "[ERROR  ] ${nb_error} error(s) detected";
        return;
    fi;
}

import_main $*








