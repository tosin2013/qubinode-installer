# lib/qubinode_functions.sh

A library of bash functions for getting the kvm host ready for ansible.

## Overview

This contains the majority of the functions required to
get the system to a state where ansible and python is available.

## Index

* [is_root()](#is_root)
* [run_su_cmd()](#run_su_cmd)
* [getPrimaryDisk()](#getprimarydisk)
* [toaddr()](#toaddr)
* [tonum()](#tonum)
* [return_netmask_ipaddr()](#return_netmask_ipaddr)
* [get_primary_interface()](#get_primary_interface)
* [libvirt_network_info()](#libvirt_network_info)
* [verify_networking_info()](#verify_networking_info)
* [pre_os_check()](#pre_os_check)
* [check_rhsm_status()](#check_rhsm_status)
* [verify_rhsm_status()](#verify_rhsm_status)
* [register_system()](#register_system)
* [confirm()](#confirm)
* [confirm_correct()](#confirm_correct)
* [createmenu()](#createmenu)
* [read_sensitive_data()](#read_sensitive_data)
* [rhsm_get_reg_method()](#rhsm_get_reg_method)
* [accept_sensitive_input()](#accept_sensitive_input)
* [rhsm_credentials_prompt()](#rhsm_credentials_prompt)
* [ask_user_for_rhsm_credentials()](#ask_user_for_rhsm_credentials)
* [ask_for_admin_user_pass()](#ask_for_admin_user_pass)
* [check_additional_storage()](#check_additional_storage)
* [ask_idm_password()](#ask_idm_password)
* [set_idm_static_ip()](#set_idm_static_ip)
* [ask_about_domain()](#ask_about_domain)
* [connect_existing_idm()](#connect_existing_idm)
* [get_idm_server_ip()](#get_idm_server_ip)
* [get_idm_admin_user()](#get_idm_admin_user)
* [ask_about_idm()](#ask_about_idm)
* [deploy_new_idm()](#deploy_new_idm)
* [install_packages()](#install_packages)
* [display_help()](#display_help)
* [qubinode_maintenance_options()](#qubinode_maintenance_options)

### is_root()

#### Exit codes

* **0**: if root user

### run_su_cmd()

#### Exit codes

* **0**: if successful

### getPrimaryDisk()

Trys to determine which disk device is assosiated with the root mount /.

### toaddr()

Takes the output from the function tonum and converts it to a network address
then setting the result as a varible.

#### Example

```bash
toaddr $NETMASKNUM NETMASK
```

#### Arguments

* **$1** (number): returned by tonum
* **$2** (variable): to set the result to

#### Output on stdout

* Returns a valid network address

### tonum()

Performs bitwise operation on each octet by it's host bit lenght adding each
result for the total. 

#### Example

```bash
tonum $IPADDR IPADDRNUM
tonum $NETMASK NETMASKNUM
```

#### Arguments

* **$1** (the): ip address or netmask
* **$2** (the): variable to store the result it   

#### Output on stdout

* The bitwise number for the specefied network info

### return_netmask_ipaddr()

Returns the broadcast, netmask and network for a given ip address and netmask.

#### Example

```bash
return_netmask_ipaddr 192.168.2.11/24
return_netmask_ipaddr 192.168.2.11 255.255.255.0
```

#### Arguments

* **$1** (ipinfo): Accepts either ip/cidr or ip/mask

### get_primary_interface()

Discover which interface provides internet access and use that as the
default network interface. Determines the follow info about the interface.
* network device name
* ip address
* gateway
* network
* mac address
* pointer record (ptr) notation for the ip address

### libvirt_network_info()

Give user the choice of creating a NAT or Bridge libvirt network or to use
an existing libvirt network.

### verify_networking_info()

Asks user to confirm discovered network information.

#### See also

* [get_primary_interface](#get_primary_interface)

### pre_os_check()

Determine if host is RHEL and sets the vars:
* rhel_release
* rhel_major
* os_name

### check_rhsm_status()

If host is RHEL, verify subcription-manager command is available.
Exists the installer if subscription-manager not found.
If subscription-manager is found, determine if the host is registered to Red Hat.

### verify_rhsm_status()

Deteremine if the registered RHEL host is has a subscription attached to it.

### register_system()

Register the RHEL host to Red Hat

### confirm()

Confirm with user if they want to continue with a given input or choice.

### confirm_correct()

Confirms if the user input is correct.

### createmenu()

A generic user choice menu used to provide user with choice.

### read_sensitive_data()

Outputs asterisks when sensitive data is entered by the user.

### rhsm_get_reg_method()

Ask the user if they want to register the host to Red Hat using username/password or activationkey/org-id.

### accept_sensitive_input()

Takes in senstive input from user.

### rhsm_credentials_prompt()

Ask user for credentials to register system to Red Hat.        

### ask_user_for_rhsm_credentials()

This is a wrapper to call functions rhsm_get_reg_method and rhsm_credentials_prompt.

### ask_for_admin_user_pass()

Ask the user for their password.

### check_additional_storage()

If multiple disk devices are found on the kvm host, ask the user if they
would like to dedicate a disk device for /var/lib/libivrt/images.

### ask_idm_password()

Ask user to set a password that will be used for the IdM server.

### set_idm_static_ip()

Define a static ip address for the IdM server.

### ask_about_domain()

Ask user to enter their dns zone name.

### connect_existing_idm()

Gather the connection information from a existing IdM server.

### get_idm_server_ip()

Get the ip address for a existing IdM server.

### get_idm_admin_user()

Get the admin username for a existing IdM server.

### ask_about_idm()

Gather data for IdM server deployment.

### deploy_new_idm()

Gather required info for deploying a new IdM server.

### install_packages()

Install required baseline packages

### display_help()

Displays help menu.

### qubinode_maintenance_options()

The qubinode-installer -m options.

