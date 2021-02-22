#!/usr/bin/env bash

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    set -o xtrace       # Trace the execution of the script (debug)
fi

set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline

## Required Vars
PROJECT_NAME="qubinode-installer"
QUBINODE_URL="${QUBINODE_URL:-https://github.com/Qubinode/qubinode-installer}"
QUBINODE_BRANCH="${QUBINODE_BRANCH:-newinstaller}"
PROJECT_DIR="$HOME/${PROJECT_NAME}"
QUBINODE_ZIP_URL="${QUBINODE_URL}/${PROJECT_NAME}/archive"
QUBINODE_TAR_URL="${QUBINODE_URL}/${PROJECT_NAME}/tarball"
QUBINODE_REMOTE_ZIP_FILE="${QUBINODE_ZIP_URL}/${QUBINODE_BRANCH}.zip"
QUBINODE_REMOTE_TAR_FILE="${QUBINODE_TAR_URL}/${QUBINODE_BRANCH}"
QUBINODE_BASH_VARS_FILE="${PROJECT_DIR}/qubinode_vars.txt"
QUBINODE_VAULT_FILE="${PROJECT_DIR}/playbooks/vars/qubinode_vault.yml"

# starting the qubinode installer 
function setup_qubinode ()
{
    download_qubinode_project
    cd "${PROJECT_DIR}/"
    printf '%s\n\n' "Running qubinode-installer -m setup"
    ./"${PROJECT_NAME}" -m setup
}

# Start qubinode deployment with config
function setup_qubinode_with_config () 
{
    download_qubinode_project
    test -d "${PROJECT_DIR}"

    if [ "A${qubinode_vault_file}" != "A" ]
    then
        cp "${qubinode_vault_file}" "${QUBINODE_VAULT_FILE}"
    fi

    if [ "A${qubinode_config_file}" != "A" ]
    then
        cp "${qubinode_config_file}" "${QUBINODE_BASH_VARS_FILE}"
    fi

    if [ -f "${QUBINODE_BASH_VARS_FILE}" ]
    then
        cd "${PROJECT_DIR}/"
        printf '%s\n\n' "Running qubinode-installer -m setup"
        ./"${PROJECT_NAME}" -m setup
    else
        printf '%s\n' "Error: ${QUBINODE_BASH_VARS_FILE} does not exist"
        exit 1
    fi
}

# start the qubinode installer check and download if does not exist
function download_qubinode_project ()
{
    local util_cmds="wget curl unzip tar"

    if [ ! -d "${PROJECT_DIR}" ]
    then
        if which curl> /dev/null 2>&1 && which tar> /dev/null 2>&1
        then
            printf '%s\n' "Downloading ${QUBINODE_REMOTE_TAR_FILE} with curl"
            cd "${HOME}"
            curl -LJ -o "${PROJECT_NAME}.tar.gz" "${QUBINODE_REMOTE_TAR_FILE}" > /dev/null 2>&1
            mkdir "${PROJECT_NAME}"
            printf '%s\n' "Untaring ${PROJECT_NAME}.tar.gz"
            tar -xzf "${PROJECT_NAME}.tar.gz" -C "${PROJECT_NAME}" --strip-components=1
	        rm -f "${PROJECT_NAME}.tar.gz" 
        elif which curl> /dev/null 2>&1 && which unzip> /dev/null 2>&1
        then
            printf '%s\n' "Downloading ${QUBINODE_REMOTE_TAR_FILE} with curl"
            cd "${HOME}"
            curl -LJ -o "${QUBINODE_BRANCH}.zip" "${QUBINODE_REMOTE_ZIP_FILE}"
            printf '%s\n' "Unzipping ${PROJECT_NAME}.tar.gz"
            unzip "${QUBINODE_BRANCH}.zip" > /dev/null 2>&1
            rm -f "${QUBINODE_BRANCH}.zip"
            mv "${PROJECT_NAME}-${QUBINODE_BRANCH}" "${PROJECT_NAME}"
        elif which wget> /dev/null 2>&1 && which tar> /dev/null 2>&1
        then
            printf '%s\n' "Downloading ${QUBINODE_REMOTE_TAR_FILE} with wget"
            cd "${HOME}"
            wget "${QUBINODE_REMOTE_TAR_FILE}" -O "${PROJECT_NAME}.tar.gz"
            mkdir "${PROJECT_NAME}"
            printf '%s\n' "Untaring ${PROJECT_NAME}.tar.gz"
            tar -xzf "${PROJECT_NAME}.tar.gz" -C "${PROJECT_NAME}" --strip-components=1 > /dev/null 2>&1
	        rm -f "${PROJECT_NAME}.tar.gz"
        elif which wget> /dev/null 2>&1 && which unzip> /dev/null 2>&1
        then
            printf '%s\n' "Downloading ${QUBINODE_REMOTE_TAR_FILE} with wget"
            cd "${HOME}"
            wget "${QUBINODE_REMOTE_ZIP_FILE}"
            printf '%s\n' "Unzipping ${PROJECT_NAME}.tar.gz"
            unzip "${QUBINODE_BRANCH}.zip" > /dev/null 2>&1
            rm -f "${QUBINODE_BRANCH}.zip"
            mv "${PROJECT_NAME}-${QUBINODE_BRANCH}" "${PROJECT_NAME}"
        else
            local count=0
            for util in $util_cmds
            do
                if ! which $util> /dev/null 2>&1
                then
                    missing_cmd[count]="$util"
                    count=$((count+1))
                fi
            done
            printf '%s\n' "Error: could not find the following ${#missing_cmd[@]} utilies: ${missing_cmd[*]}"
            exit 1
        fi
    else
        printf '%s\n' "The Qubinode project directory ${PROJECT_DIR} already exists."
        printf '%s\n' "Run ${PROJECT_DIR}/qubinode-installer -h to see additional options"
        exit 1
    fi
}

# Remove qubinode installer and conpoments
function remove_qubinode_folder ()
{
    if [ -d  "${PROJECT_DIR}" ];
    then 
        printf '%s\n' "Removing ${PROJECT_DIR}"
        sudo rm -rf "${PROJECT_DIR}" 
    fi 

    if [ -d /usr/share/ansible-runner-service ] && [ ! -f /etc/systemd/system/ansible-runner-service.service ];
    then 
      printf '%s\n' "Removing ansible-runner-service"
      sudo rm -rf /usr/share/ansible-runner-service
      sudo rm -rf /usr/local/bin/ansible_runner_service
      sudo rm -rf /tmp/ansible-runner-service/
    fi 
}

# displays usage
function script_usage() {
    cat << EOF
Usage:
     -h|--help                  Displays this help
     -v|--vault                 Qubinode unencrypted vault file, requires -c
     -c|--config                Install Qubinode installer using config file
     -d|--download              Download the qubinode project 
     -r|--remove                Remove Qubinode installer 
EOF
}

## returns zero/true if root user
function is_root () {
    return $(id -u)
}

function arg_error ()
{
    printf '%s\n' "$1" >&2
    exit 1
}

function main ()
{
    # Exit if this is executed as the root user
    if is_root 
    then
        echo "Error: qubi-installer should be run as a normal user, not as root!"
        exit 1
    fi

    # Transform long options to short ones
    for arg in "$@"; do
      shift
      case "$arg" in
        "--help")      set -- "$@" "-h" ;;
        "--config")    set -- "$@" "-c" ;;
        "--download")  set -- "$@" "-d" ;;
        "--remove")    set -- "$@" "-r" ;;
        "--vault")     set -- "$@" "-v" ;;
        *)             set -- "$@" "$arg"
      esac
    done

    ## set defaults
    qubinode_config_file=""
    qubinode_vault_file=""
    download_qubinode=""
    remove_qubinode=""

    # Parse short options
    OPTIND=1
    while getopts "hc:drv:" opt
    do
      case "$opt" in
        "h") script_usage; exit 0 ;;
        "c") qubinode_config_file="$OPTARG";;
        "d") download_qubinode=yes ;;
        "r") remove_qubinode=yes ;;
        "v") qubinode_vault_file="$OPTARG";;
        "?") script_usage >&2; exit 1 ;;
      esac
    done
    shift $(expr $OPTIND - 1) # remove options from positional parameters

    # If no arguments pass, run default option to install OpenShift
    if (( "$OPTIND" == 1 ))
    then
        setup_qubinode
    elif [ "A${qubinode_config_file}" != "A" ] && [ "A${qubinode_vault_file}" != "A" ]
    then
        ## verify config file exist
        if [ ! -f "${qubinode_config_file}" ]
        then
            printf '%s\n' "Error: ${qubinode_config_file} does not exist"
            exit 1
        fi

        ## verify vault file exist
        if [ ! -f "${qubinode_vault_file}" ]
        then
            printf '%s\n' "Error: ${qubinode_vault_file} does not exist"
            exit 1
        fi

        # download and setup
        setup_qubinode_with_config
    elif [ "A${qubinode_config_file}" != "A" ]
    then
        ## verify config file exist
        if [ ! -f "${qubinode_config_file}" ]
        then
            printf '%s\n' "Error: ${qubinode_config_file} does not exist"
            exit 1
        else
            cp "${qubinode_config_file}" "${QUBINODE_BASH_VARS_FILE}"
        fi

        # download and setup
        setup_qubinode_with_config
    elif [ "A${remove_qubinode}" == "Ayes" ]
    then
        remove_qubinode_folder
    elif [ "A${download_qubinode}" == "Ayes" ]
    then
        download_qubinode_project
    else
        script_usage 
    fi
}


main "$@"