#!/bin/bash 
#set -xe 

function generate_sshkey(){
   ssh-keygen -f "${HOME}/.ssh/id_rsa" -q -N '' 
}

# setting ansible config enviornment for ansible runner 
function set_ansible_config_env(){
    export ANSIBLE_CONFIG="${HOME}/qubinode-installer/ansible.cfg"
    echo 'export ANSIBLE_CONFIG="'"${HOME}"'/qubinode-installer/ansible.cfg"' >> ${HOME}/.bashrc
}


