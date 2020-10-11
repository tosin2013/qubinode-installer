function configure_rhel8_packages(){
    sudo dnf clean all > /dev/null 2>&1
    sudo dnf install -y -q -e 0  python3-pip ansible git vim  python3-devel gcc
    sudo dnf module install -y -q -e 0 container-tools
}

function configure_centos8_packages(){
    sudo dnf clean all > /dev/null 2>&1
    sudo dnf install -y -q -e 0  python3-pip ansible git vim  python3-devel gcc
    sudo dnf -y module disable container-tools
    sudo dnf -y install 'dnf-command(copr)'
    sudo dnf -y copr enable rhcontainerbot/container-selinux
    sudo curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_8/devel:kubic:libcontainers:stable.repo
    sudo dnf -y install  buildah skopeo podman
}

function configure_fedora_packages(){
    sudo dnf clean all > /dev/null 2>&1
    sudo dnf install -y -q -e 0  python3-pip ansible git vim  python3-devel gcc
    sudo dnf  install -y -q -e 0  buildah skopeo podman -y
}

function configure_rhel7_packages(){
    sudo yum clean all > /dev/null 2>&1
    sudo yum install -y -q -e 0 python python3-pip python2-pip python-dns  gcc
    sudo yum install -y -q -e 0 ansible git
    sudo dnf  install -y -q -e 0  buildah skopeo podman -y
}

function configure_rhel8_subscriptions(){
    sudo subscription-manager repos --enable="rhel-8-for-x86_64-baseos-rpms" > /dev/null 2>&1
    sudo subscription-manager repos --enable="rhel-8-for-x86_64-appstream-rpms" > /dev/null 2>&1
    sudo subscription-manager repos --enable="ansible-2.9-for-rhel-8-x86_64-rpms" > /dev/null 2>&1
}


function configure_rhel7_subscriptions(){
    sudo subscription-manager repos --enable="rhel-8-for-x86_64-baseos-rpms" > /dev/null 2>&1
    sudo subscription-manager repos --enable="rhel-7-server-extras-rpms" > /dev/null 2>&1
    sudo subscription-manager repos --enable="rhel-7-server-ansible-2.9-rpms" > /dev/null 2>&1
}

function install_requirements(){
    sudo pip3 install -r "$(pwd)/lib/requirements-to-freeze.txt"
    ansible-galaxy install -r "$(pwd)/playbooks/requirements.yml" --force
}

function configure_vault_key(){
    if [ ! -f ${HOME}/.vaultkey ];
    then
      openssl rand -base64 512|xargs > "${HOME}/.vaultkey"
    fi
}
