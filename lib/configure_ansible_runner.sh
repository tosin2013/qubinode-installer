#!/bin/bash 

# Install ansible runner 
function install_ansible_runner_service(){
    if [ ! -d /usr/share/ansible-runner-service ];
    then
        cd /tmp  || exit
        git clone https://github.com/ansible/ansible-runner-service.git
        sudo  mkdir -p /etc/ansible-runner-service
        sudo mkdir -p /usr/share/ansible-runner-service/{artifacts,env,project,inventory,client_cert}
        sudo cp /tmp/ansible-runner-service/*.py   /usr/share/ansible-runner-service/
        sudo cp /tmp/ansible-runner-service/*.yaml   /usr/share/ansible-runner-service/
        sudo cp -r /tmp/ansible-runner-service/runner_service /usr/share/ansible-runner-service/runner_service
        cd /tmp/ansible-runner-service  || exit
        sudo  python3 setup.py install --record installed_files --single-version-externally-managed
        sudo cp /usr/local/bin/ansible_runner_service /usr/bin/
        #sudo ansible_runner_service
    fi 
}


function ansible_runner_config_yaml(){
sudo tee -a /etc/ansible-runner-service/config.yaml<<EOF
---
version: 1

# playbooks_root_dir
# location of the playbooks that the service will start
# playbooks_root_dir: './samples'
playbooks_root_dir: '${HOME}/qubinode-installer/'

# port
# tcp port for the service to listen to
# port: 5001
#
# ip_address
# Specific IP address to bind to
# ip_address: '0.0.0.0'
target_user: root

#event_cache_size: 3

# maximum age of an artifact folder in days
# set to 0 to disable the automatic removal of old artifact folders
# artifacts_remove_age: 7

# how frequently the old artifacts should be removed in days
# artifacts_remove_frequency: 1

EOF
}

function configure_ansible_runner_systemd(){
    if [ ! -f /usr/share/ansible-runner-service ];
    then
      mkdir -p ${HOME}/qubinode-installer/env
      ln -s ${HOME}/qubinode-installer/playbooks  ${HOME}/qubinode-installer/project 
      sudo ln -s  ${HOME}/qubinode-installer/playbooks /etc/ansible-runner-service/project
      if [ ! -f /etc/ansible-runner-service/config.yaml ]
      then 
        ansible_runner_config_yaml
      fi
      sudo cp /tmp/ansible-runner-service/misc/systemd/ansible-runner-service.service /etc/systemd/system
      sudo systemctl enable ansible-runner-service.service
      sudo systemctl start ansible-runner-service.service
      #sudo systemctl status ansible-runner-service.service
    fi
}
