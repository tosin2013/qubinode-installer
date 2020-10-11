#!/usr/bin/env bash

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    set -o xtrace       # Trace the execution of the script (debug)
fi

set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline

# Exports the qubinode installer into the home directory
function extract_quibnode_installer(){
    echo "${1}"
    unzip "$HOME/${1}"
    rm "$HOME/${1}"
    NAMED_RELEASE=$(echo ${1} | sed -e 's/.zip//')
    mv qubinode-installer-${NAMED_RELEASE} qubinode-installer
}

# downloads the qubinode code using curl 
function curl_download(){
    if [ -x /usr/bin/curl ] ; then
        cd $HOME
        #wget https://github.com/Qubinode/qubinode-installer/archive/master.zip
        #extract_quibnode_installer master.zip
        curl -OL  https://github.com/tosin2013/qubinode-installer/archive/release-2.4.3.zip
        extract_quibnode_installer release-2.4.3.zip
    fi 
}

# starting the qubinode installer 
function start_qubinode_install(){
    cd $HOME/qubinode-installer/
    ./qubinode-installerv2.sh
}

function git_clone_code(){
  git clone https://github.com/tosin2013/qubinode-installer.git
  cd qubinode-installer
  git checkout release-2.4.3
}

# calling a wget to download  qubinode node code
function wget_download(){
    cd $HOME
    #wget https://github.com/Qubinode/qubinode-installer/archive/master.zip
    #extract_quibnode_installer master.zip
    wget https://github.com/tosin2013/qubinode-installer/archive/release-2.4.3.zip
    extract_quibnode_installer release-2.4.3.zip
}

# start the qubinode installer check and download if does not exist
function start_qubinode_download(){
  if  [ ! -d ${HOME}/qubinode-installer ];
  then 
    if [ ! -x /usr/bin/unzip ] ; then
      echo "unzip found on system."
      echo "Please install unzip to continue with install"
      exit 1
    fi

    if [ -x /usr/bin/git ] ; then
      git_clone_code
      start_qubinode_install
    elif [ -x /usr/bin/curl ] ; then
      curl_download
      start_qubinode_install
    elif [ -x /usr/bin/wget ] ; then
      wget_download
      start_qubinode_install
    else 
      echo "wget or curl not found on system."
      echo "Please install curl or wget to continue with install"
      exit 1
    fi
  fi
}

# Remove qubinode installer and conpoments
function remove_qubinode_folder(){
    if [ -d  ${HOME}/qubinode-installer ];
    then 
        sudo rm -rf ${HOME}/qubinode-installer
    fi 

    if [ -d /usr/share/ansible-runner-service ] && [ ! -f /etc/systemd/system/ansible-runner-service.service ];
    then 
      sudo rm -rf /usr/share/ansible-runner-service
      sudo rm -rf /usr/local/bin/ansible_runner_service
      sudo rm -rf /tmp/ansible-runner-service/
    fi 

    if [ -f ${HOME}/.ssh/id_rsa ];
    then
      sudo rm -rf ${HOME}/.ssh/id_rsa 
      sudo rm -rf ${HOME}/.ssh/id_rsa.pub
    fi  

}

# displays usage
function script_usage() {
    cat << EOF
Usage:
     -h|--help                  Displays this help
     -v|--verbose               Displays verbose output
    -i|--install              Install Qubinode installer 
    -d|--delete                 Remove Qubinode installer 
EOF
}

# Parsing menu items 
function parse_params() {
    local param
    while [[ $# -gt 0 ]]; do
        param="$1"
        shift
        case $param in
            -h | --help)
                script_usage
                exit 0
                ;;
            -v | --verbose)
                verbose=true
                ;;
            -i | --install)
                start_qubinode_download
                ;;
            -d | --delete)
                remove_qubinode_folder
                ;;
            *)
                echo  "Invalid parameter was provided: $param" 
                script_usage
                exit 1
                ;;
        esac
    done
}


# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {
    parse_params "$@"
}

# Start main function 
if [ -z $@ ];
then 
  echo "Please see script usage."
  script_usage
fi 

main "$@"

