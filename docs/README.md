#  Qubinode Overview

A Qubinode is a bare metal node that uses the qubinode-installer to configure RHEL to function as a KVM host. The qubinode-installer can then be used to deploy additional Red Hat products as VMs running atop the Qubinode. 

# Getting Started

The first step is to get RHEL installed on your hardware

## Get Subscriptions

-  Get your [No-cost developer subscription](https://developers.redhat.com/articles/faqs-no-cost-red-hat-enterprise-linux/) for RHEL.
-  Get a Red Hat OpenShift Container Platform (OCP) [60-day evalution subscription](https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it?intcmp=701f2000000RQykAAG&extIdCarryOver=true&sc_cid=701f2000001OH74AAG).

## Install Red Hat Enterprise Linux
A bare metal system running Red Hat Enterprise Linux 8. Follow the [RHEL Installation Walkthrough](https://developers.redhat.com/products/rhel/hello-world#fndtn-rhel) to get RHEL installed on your hardware. When installing RHEL, for the software selection, **Base Environment** choose one of the following:

1. Virtualization Host
2. Server with GUI

If you choose **Server with GUI**, make sure from the **Add-ons for Selected Evironment** you select the following:

- Virtualization Hypervisor 
- Virtualization Tools

**_TIPS_**
> * If using the recommend storage of one ssd and one NVME, install RHEL on the ssd, not the NVME. 
>  * The RHEL installer will delicate the majority of your storage to /home,  you can choose **"I will configure partitioning"** to have control over this.
>  * Set root password and create admin user with sudo privilege

###  get the Qubinode install and start installation 

```shell=
cd $HOME
curl -OL https://raw.githubusercontent.com/tosin2013/qubinode-installer/python-build/lib/get_qubinode.sh
chmod +x get_qubinode.sh
# review code 
vim get_qubinode.sh
./get_qubinode.sh
```

### Qubinode Setup

Export Ansible Config 
```
export ANSIBLE_CONFIG="/home/admin/qubinode-installer/ansible.cfg"
```

start with the configure_secerts.yml 
```
cat >env/extravars<<EOF
{
   "configure_secerts": true,
   "rhsm_username": "yourusername",
   "rhsm_password": "changeme",
   "rhsm_pass": "{{ rhsm_password }}",
   "rhsm_org": "",
   "rhsm_activationkey": "",
   "admin_user_password": "changeme",
   "idm_ssh_user": "yourusername",
   "idm_dm_pwd": 'thisisaveryL0ngpaSSw0rd',
   "idm_admin_pwd": "changeme"
}
EOF
sudo python3 lib/qubinode_ansible_runner.py  qubinode-config-management.yml
rm env/extra_vars
```

Configure rhelX_host_vars
```
sudo python3 lib/qubinode_ansible_runner.py qubinode-config-management.yml  --extravars '{"collect_generic_info": true}'
```

Install ansible roles 
```
ansible-galaxy install -r  project/requirements.yml
```

Configure KVM variables
```
sudo python3 lib/qubinode_ansible_runner.py qubinode-config-management.yml  --extravars '{ "configure_kvm_host": true}'
```
Copy rhel-server-7.8-x86_64-kvm.qcow2 to home direcotry 

Configure KVM host 
```
sudo -E  python3 lib/qubinode_ansible_runner.py setup_kvmhost.yml
```
cp qubinode-configs/passwords/extravars env/extra_vars
sudo -E python3 lib/qubinode_ansible_runner.py  qubinode-config-management.yml
rm env/extra_vars

Configure IDM server 
```
sudo -E  python3 lib/qubinode_ansible_runner.py idm_vm_deployment.yml
sudo -E  python3 lib/qubinode_ansible_runner.py idm_server.yml
```

Get idm information script WIP
```
python3 lib/qubinode_status_checker.py idm  qbn-dns01.example.lab
```

Deploy RHEL 7 Server
```
rm env/extravars
cat >env/extravars<<EOF
{
   "cloud_init_vm_image": "rhel-server-7.8-x86_64-kvm.qcow2",
   "vm_teardown": false,
   "vm_recreate": false,
   "configure_rhel_vm_info": true,
   "expand_os_disk": "no",
   "rhel_7_hash": null,
   "rhel_8_hash": null,
   "rhel_release": 7,
    "rhel_enable": true,
    "rhel_extra_storage": [
       {
          "enable": false,
          "size": ""
       }
    ],
    "rhel_group": "rhel",
    "rhel_recreate": false,
    "rhel_root_disk_size": "20G",
    "rhel_vcpu": 1,
   "rhel_memory": 800,
   "rhel_name": "rhel7_example",
   "update_etc_resolv": "no",
   "vm_root_disk_size": "{{ rhel_server_vm.rhel_root_disk_size }}"
}
EOF
sudo python3 lib/qubinode_ansible_runner.py  qubinode-config-management.yml

rm env/extravars
sudo -E python3 lib/qubinode_ansible_runner.py  rhel.yml --extravars '{ "rhel_name": "rhel7_example"}'

# To tear down server
sudo -E  python3 lib/qubinode_ansible_runner.py  rhel.yml --extravars '{"rhel_name": "rhel7_example", "vm_teardown": true} '
```

Deploy RHEL 8 Server

Deploy Fedora Server. 

## Deploy a Red Hat Product

Most products depends on the latest rhel 7 or 8 qcow image. You can either manually download them or provide your RHSM api token and the installer will download these files for you.

#### Getting the RHEL 7 or 8 Qcow Image
<table>
  <tr>
   <td>Using Token
   </td>
   <td>Downloading
   </td>
  </tr>
  <tr>
   <td>Navigate to <a href="https://access.redhat.com/management/api">RHSM API</a> to generate a token and save it as <strong>rhsm_token</strong>. This token will be used to download the rhel qcow image. 
   </td>
   <td>From your web browser, navigate to <a href="https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.8/x86_64/product-software">Download Red Hat Enterprise Linux</a>. Download the qcow image matching this checksum the below checksum.
   </td>
  </tr>
</table>

Follow the same steps to get the RHEL 8 qcow image.

If you are using tokens it should be:
```
* $HOME/qubinode-installer/rhsm_token
```

If you downloaded the files instead, confirm that the project directory list the qcow images below or later versions:
```
* $HOME/qubinode-installer/rhel-server-7.8-x86_64-kvm.qcow2
* $HOME/qubinode-installer/rhel-8.2-x86_64-kvm.qcow2
```

## Install DNS server 
* [Red Hat Identity Managment](qubinode/idm.md)

At this point you refer to the [documentation](#Currently-Supported-Products) for the product you want to install.

## Currently Supported Products
* [Red Hat OpenShift Platform](qubinode/openshift4_installation_steps.md)
* [OKD - The Community Distribution of Kubernetes](qubinode/okd4_installation_steps.md)
* [Red Hat Identity Managment](qubinode/idm.md)
* [Red Hat Enterprise Linux](qubinode/rhel_vms.md)

## Products in Development
* [Ansible Automation Platform](qubinode/ansible_platform.md)
* [Red Hat Satellite](qubinode/qubinode_satellite_install.md)
