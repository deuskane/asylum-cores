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
# 2021-11-23  1.1      mrosiere Use getops
# 2025-02-18  1.2      mrosiere Split dump and import scripts
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
    echo "Usage: $0 [OPTIONS]"
    echo "Import core files from a source directory to a structured destination directory."
    echo ""
    echo "Options:"
    grep " .)\ ##" "$0" | sed -e 's/^[ \t]*.) ##//' -e 's/^/  /'
    
    echo ""
}

#-----------------------------------------------------------------------------
# import_main
#-----------------------------------------------------------------------------
# Copy core fies
#-----------------------------------------------------------------------------
function import_main()
{
    # Exit immediately if a command exits with a non-zero status.
    # Treat unset variables as an error.
    # The return value of a pipeline is the status of the last command to exit with a non-zero status, or zero if all commands in the pipeline exit successfully.
    set -euo pipefail

    src_dir="";
    dst_dir=".";
    
    while getopts ":s:d:rvh" arg; do
	case $arg in
	    s) ## Source directory (mandatory)
		src_dir=${OPTARG}
		if test ! -d "${src_dir}";
		then
		    echo "[ERROR  ] Invalid directory : ${src_dir}";
		    import_usage
		    exit -1;
		fi
		;;

	    d) ## destination directory (optional, default = .)
		dst_dir=${OPTARG}

		if test ! -d "${dst_dir}";
		then
		    echo "[ERROR  ] Invalid directory : ${dst_dir}";
		    import_usage
		    exit -1;
		fi

		;;

	    r) ## Execute (else dry run)
		dry_run=0
		;; # dry_run is initialized to 1 (true) by default. Setting to 0 means execute.

	    v) ## Verbose
		verbose=1
		;; # verbose is initialized to 0 (false) by default. Setting to 1 means verbose output.

	    h | *) ## Display help
		echo "${OPTARG}"
		import_usage
		exit 0
		;;

	esac
    done

    # Initialize default values for dry_run and verbose if not set by getopts
    : "${dry_run:=1}" "${verbose:=0}"

    # Check source directory
    if test -z "${src_dir}";
    then
        echo "[ERROR  ] Undefine source directory";
        import_usage $0
        return;
    fi

    # Check for the presence of dump.sh in the destination directory.
    # This script assumes dump.sh is a companion script for managing cores.
    if test ! -f "${dst_dir}/dump.sh";
    then
        echo "[ERROR  ] File \"${dst_dir}/dump.sh\" not found";
        import_usage $0
        return;
    fi

    # Define the expected magic header for core files.
    local -r CORE_MAGIC_HEADER="CAPI"
    local -r EXPECTED_GIT_BRANCH="main"

    echo "[INFO   ] Find core files"

    # Use find with -print0 and read -d $'\0' to handle filenames with spaces correctly.
    local -A core_map # Declare an associative array to detect duplicate VLNVs.
    local nb_error=0

    printf "[INFO   ] %-20s | %-20s | %-20s | %-10s | Status\n" "Vendor" "Library" "Name" "Version"
    printf "[INFO   ] %-20s | %-20s | %-20s | %-10s | %s\n" "--------------------" "--------------------" "--------------------" "----------" "--------------------------------------------------"

    find "${src_dir}" -name "*.core" -print0 | while IFS= read -r -d $'\0' src_core;
    do
        # Check for the magic header at the beginning of the file.
        if [[ "$(head -c ${#CORE_MAGIC_HEADER} "${src_core}")" != "${CORE_MAGIC_HEADER}" ]];
        then
            printf "[WARNING] %-20s | %-20s | %-20s | %-10s -> " "" "" "" "" 
            printf "${src_core}"
            printf "Missing CAPI header, skipping\n"
            continue
        fi

        [[ ${verbose} -gt 0 ]] && echo "[DEBUG  ] Processing: ${src_core}"

        local core_dir
        core_dir="$(dirname "${src_core}")"
        
        # Extract VLNV (Vendor, Library, Name, Version) from the core file.
        # Assumes the 'name' line is in the format 'name:vendor:library:name:version'.
        # This parsing is brittle and depends on the exact format of the .core file.
        local fullname
        fullname="$(grep '^name' "${src_core}" | head -n1)"
        local vendor library name version
        vendor="$(echo "${fullname}" | cut -d':' -f2 | tr -cd '[:graph:]')"
        library="$(echo "${fullname}" | cut -d':' -f3 | tr -cd '[:graph:]')"
        name="$(echo "${fullname}" | cut -d':' -f4 | tr -cd '[:graph:]')"
        version="$(echo "${fullname}" | cut -d':' -f5 | tr -cd '[:graph:]')"
        local vlnv="${vendor}-${library}-${name}-${version}"

        printf "[INFO   ] %-20s | %-20s | %-20s | %-10s | " "${vendor}" "${library}" "${name}" "${version}"

        # Validate extracted VLNV components.
        if [[ -z "${vendor}" ]] || [[ -z "${library}" ]] || [[ -z "${name}" ]] || [[ -z "${version}" ]];
        then
            printf "ERROR: Invalid VLNV (one or more fields are empty)\n"
            nb_error=$((nb_error+1))
            continue
        fi
        
        # Check for duplicate VLNV entries.
        if [ ${core_map[${vendor}${library}${name}]+_} ];
        then
            printf "ERROR: Duplicate VLNV. Already found in %s\n" "${core_map[${vendor}${library}${name}]}"
            nb_error=$((nb_error+1))
            continue
        else
            core_map[${vendor}${library}${name}]=${src_core}
        fi
        
        # Validate version format (e.g., 1.0.0). Bash-specific regex.
        if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]];
        then
            printf "ERROR: Version format is invalid (expected X.Y.Z)\n"
            nb_error=$((nb_error+1))
            continue
        fi

        local formatted_version="v${version//./_}"
        local base_core_name
        base_core_name="$(basename "${src_core}" .core)"
        local dst_core="${dst_dir}/${vendor}/${library}/${name}/${base_core_name}_${formatted_version}.core"
        
        # Check if destination core file already exists.
        if [[ -f ${dst_core} ]];
        then
            printf "WARNING: Existing destination core will be overwritten\n"
            printf "[WARNING] %-20s | %-20s | %-20s | %-10s -> " "" "" "" "" 
        fi

        # Retrieve Git repository information.
        local git_url git_version git_branch
        git_url="$(cd "${core_dir}" && git config --get remote.origin.url)"
        if [[ -z ${git_url} ]];
        then
            printf "ERROR: Cannot get git remote origin URL from %s\n" "${core_dir}"
            nb_error=$((nb_error+1))
            continue
        fi

        git_version="$(cd "${core_dir}" && git rev-parse HEAD)"
        if [[ -z ${git_version} ]];
        then
            printf "ERROR: Cannot get git HEAD revision from %s\n" "${core_dir}"
            nb_error=$((nb_error+1))
            continue
        fi

        git_branch="$(cd "${core_dir}" && git rev-parse --abbrev-ref HEAD)"
	if [[ "${git_branch}" != "${EXPECTED_GIT_BRANCH}" ]];
	then
	    printf "ERROR: Current git branch '%s' is not '%s'\n" "${git_branch}" "${EXPECTED_GIT_BRANCH}"
            nb_error=$((nb_error+1))
	    continue
	fi

        # Extract git user and repository name. Assumes GitHub URL format.
        local git_user git_repo
        if [[ "${git_url}" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
            git_user="${BASH_REMATCH[1]}"
            git_repo="${BASH_REMATCH[2]}"
        else
            printf "ERROR: Unsupported Git URL format: %s\n" "${git_url}"
            nb_error=$((nb_error+1))
            continue
        fi
	
        printf "OK: '%s'\n" "${dst_core}"
		
        if [[ ${dry_run} -eq 0 ]]; # If dry_run is 0, execute the commands.
        then
            mkdir -p "$(dirname "${dst_core}")"
            cp "${src_core}" "${dst_core}"

            # Force tagging might overwrite existing tags. Consider if this is the desired behavior.
            (cd "${core_dir}" && git tag -f -a "${vlnv}" -m "Tag ${vlnv}")

            # Append provider information to the copied core file.
            {
                echo ""
                echo "# Next lines is a pragma, don't modify"
                echo "#<PROVIDER_BEGIN>"
                echo "provider  :"
                echo "  name    : github"
                echo "  user    : ${git_user}"
                echo "  repo    : ${git_repo}"
                echo "  version : ${vlnv}"
                echo " #version : ${git_version}" # Original git commit hash, commented out.
                echo "#<PROVIDER_END>"
            } >> "${dst_core}"
        fi
    done

    if [[ ${nb_error} -gt 0 ]];
    then
        echo "[ERROR  ] ${nb_error} error(s) detected. Aborting."
        exit 1 # Exit with error code if any errors occurred.
    fi

    echo "[INFO   ] Import process completed successfully."
}

import_main $*
