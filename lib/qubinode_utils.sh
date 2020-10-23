#!/bin/bash 
#set -xe 

function generate_sshkey(){
   ssh-keygen -f "${HOME}/.ssh/id_rsa" -q -N '' 
   sudo mkdir -p /root/.ssh/
   sudo ln -s ~/.ssh/id_rsa  /root/.ssh/
}

# setting ansible config enviornment for ansible runner 
function set_ansible_config_env(){
    export ANSIBLE_CONFIG="${HOME}/qubinode-installer/ansible.cfg"
    if grep -Fxq "ANSIBLE_CONFIG" ${HOME}/.bashrc
    then
        source ${HOME}/.bashrc
    else
        echo 'export ANSIBLE_CONFIG="'"${HOME}"'/qubinode-installer/ansible.cfg"' >> ${HOME}/.bashrc
        source ${HOME}/.bashrc
    fi

    sed -i "s|vault_password_file  = ~/.vaultkey|vault_password_file  = $HOME/.vaultkey|g" ${HOME}/qubinode-installer/ansible.cfg
}

