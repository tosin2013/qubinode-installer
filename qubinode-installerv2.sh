#!/usr/bin/env bash
set -E
set -o functrace
set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

# Uncomment for debugging
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x


# Define colours
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
def=$'\e[1;49m'
end=$'\e[0m'

project_dir="`dirname \"$0\"`"

# Source in files 
. "${project_dir}/lib/qubinode_rhsm.sh"
. "${project_dir}/lib/qubinode_rpm_packages.sh"
. "${project_dir}/lib/configure_ansible_runner.sh"
. "${project_dir}/lib/qubinode_utils.sh"

function main(){
    if [ -f /etc/redhat-release ];
    then
        echo "Checking Red Hat Release Type"
        if cat /etc/redhat-release  | grep '8.[0-9]' > /dev/null 2>&1; then
            printf "%s\n" "${grn} $(cat /etc/redhat-release) detected. Configuring system for qubinode installer${end}"
            check_rhsm_status
            configure_rhel8_subscriptions
            configure_rhel8_packages
            install_requirements
            configure_vault_key
            install_ansible_runner_service
            generate_sshkey
            set_ansible_config_env
            configure_ansible_runner_systemd
        elif cat /etc/redhat-release  | grep '7.[0-9]' > /dev/null 2>&1; then
            printf "%s\n" "${grn} $(cat /etc/redhat-release) detected. Configuring system for qubinode installer${end}"
            printf "%s\n" "${red} $(cat /etc/redhat-release) Not tested or supported.{end}"
            exit 1
            check_rhsm_status
            configure_rhel7_subscriptions
        elif cat /etc/redhat-release  | grep 'Fedora release 3[0-9]' > /dev/null 2>&1; then
            printf "%s\n" "${grn} $(cat /etc/redhat-release) detected. Configuring system for qubinode installer${end}"
            configure_fedora_packages
            install_requirements
            configure_vault_key
            install_ansible_runner_service
            generate_sshkey
            set_ansible_config_env
            configure_ansible_runner_systemd
        else
            printf "%s\n"  "${red}Unknown RHEL Based server${end}"
            exit 1
        fi
    else
        printf "%s\n"  "${red}Unknown system please see requirements doc.${end}"
        exit 1
    fi 
}

main
