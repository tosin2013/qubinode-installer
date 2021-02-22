#!/bin/bash

# @file lib/qubinode_functions.sh
# @brief A library of bash functions for getting the kvm host ready for ansible.
# @description
#  This contains the majority of the functions required to
#  get the system to a state where ansible and python is available.


##---------------------------------------------------------------------
## Functions for setting up sudoers
##---------------------------------------------------------------------
#@description
# Check if the current user is root.
# @exitcode 0 if root user
function is_root () {
    return $(id -u)
}

#@description
# Validates that the argument options are valid, for example.
# If the agruments -s-p where pass to the installer. The '-' between s and p
# will not be use as a value of s. 
function check_args () {
    if [[ $OPTARG =~ ^-[p/c/h/d/a/v/m]$ ]]
    then
      echo "Invalid option argument $OPTARG, check that each argument has a value." >&2
      exit 1
    fi
}

#@description
# Executes 'su -c <cmd>'
# @exitcode 0 if successful
function run_su_cmd() {
    # this fucntion is used with setup_sudoers
    local cmd=$@
    su -c "$cmd"
    return $?
}

#@description
# Adds the current user to sudoers and make it password-less access.
# If this is unsuccessful it will cause the qubinode-installer to exit.
function setup_sudoers () {
   local __admin_pass="$1"
   if [ "A${__admin_pass}" == "Anone" ]
   then
       echo "Current user password is required."
       exit 1
   fi
   local TMP_RESULT=$(mktemp)
   local TMP_RESULT2=$(mktemp)
   local HAS_SUDO="none"
   local MSG="We need to setup up your username ${cyn:?}${QUBINODE_ADMIN_USER}${end:?} for sudo password less access."
   local SU_MSG="Your username ${cyn:?}${QUBINODE_ADMIN_USER}${end:?} is not in the sudoers file."
   local SU_MSG2="Please enter the ${cyn:?}root${end:?} user password to setup ${cyn:?}${QUBINODE_ADMIN_USER}${end:?} sudoers."
   local SUDOERS_TMP=$(mktemp)
   local SUDO_MSG="Creating user ${QUBINODE_ADMIN_USER} sudoers file /etc/sudoers.d/${QUBINODE_ADMIN_USER}"
   # clear sudo cache
   sudo -k

   # Check if user is setup for sudo
   echo "$__admin_pass" | sudo -S ls 2> "$TMP_RESULT" 1> /dev/null || HAS_SUDO=no
   echo "${QUBINODE_ADMIN_USER} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS_TMP}"
   chmod 0440 "${SUDOERS_TMP}"

   if [ "$HAS_SUDO" == "no" ]
   then
       printf "%s\n" ""
       printf "%s\n" "  ${blu:?}Setup Sudoers${end:?}"
       printf "%s\n" "  ${blu:?}***********************************************************${end:?}"
       printf "%s\n\n" "  ${MSG}"

       if grep -q "${QUBINODE_ADMIN_USER} is not in the sudoers file" "$TMP_RESULT"
       then
           local CMD="cp -f ${SUDOERS_TMP} /etc/sudoers.d/${QUBINODE_ADMIN_USER}"
           printf "%s\n" "  ${SU_MSG}"
	       confirm "  Continue setting up sudoers for ${QUBINODE_ADMIN_USER}? ${cyn:?}yes/no${end:?}"
	       if [ "A${response}" == "Ano" ]
           then
               printf "%s\n" "  You can manually setup sudoers then re-run the installer."
	           exit 0
	       fi
              
           ## Use root user password to setuo sudoers 
           printf "%s\n" "  ${SU_MSG2}"
           retry=0
           maxRetries=3
           retryInterval=15

           until [ ${retry} -ge ${maxRetries} ]
           do
               run_su_cmd "$CMD" && break
               retry=$[${retry}+1]
               printf "%s\n" "  ${cyn:?}Try again. Enter the root user ${end:?}"
           done

           if [ ${retry} -ge ${maxRetries} ]; then
               printf "%s\n" "   ${red:?}Error: Could not authenicate as the root user.${end:?}"
               exit 1
           fi
       else
           printf "%s\n" "  ${SUDO_MSG}"
           echo "$__admin_pass" | sudo -S cp -f "${SUDOERS_TMP}" "/etc/sudoers.d/${QUBINODE_ADMIN_USER}" > /dev/null 2>&1
           echo "$__admin_pass" | sudo -S chmod 0440 "/etc/sudoers.d/${QUBINODE_ADMIN_USER}" > /dev/null 2>&1
       fi
   fi

   # Confirm sudo setup
   sudo -k
   echo "$__admin_pass" | sudo -S ls 2> "$TMP_RESULT" 1> /dev/null && HAS_SUDO=yes
   if [ "$HAS_SUDO" == "no" ]
   then
       printf "%s\n" "   ${red:?}Error: Sudo setup was unsuccesful${end:?}"
       exit
   fi
   setup_sudoers_status="sudoers_done"
   BASELINE_STATUS+=("$setup_sudoers_status")
}


##---------------------------------------------------------------------
## Get Storage Information
##---------------------------------------------------------------------
# @description
# Trys to determine which disk device is assosiated with the root mount /.
function getPrimaryDisk () {
    primary_disk="${PRIMARY_DISK:-none}"
    if [ "A${primary_disk}" == "Anone" ]
    then
        if which lsblk >/dev/null 2>&1
        then
            declare -a DISKS=()
            dev=$(eval "$(lsblk -oMOUNTPOINT,PKNAME -P| \
		    grep 'MOUNTPOINT="/"')"; echo "${PKNAME//[0-9]*/}") 
                #grep 'MOUNTPOINT="/"')"; echo "$PKNAME" | sed 's/[0-9]*$//')
            if [ "A${dev}" != "A" ]
            then
               primary_disk="$dev"
	    fi
        fi
    fi

    ## get all available disk
    mapfile -t DISKS < <(lsblk -dp | \
        grep -o '^/dev[^ ]*'|awk -F'/' '{print $3}' | \
        grep -v "${primary_disk}")
    ALL_DISK="${DISKS[*]}"

    ## Export vars for updating qubinode_vars.txt
    export PRIMARY_DISK="${primary_disk-none}"
}


## Came across this Gist that provides the functions tonum and toaddr
## https://gist.githubusercontent.com/cskeeters/278cb27367fbaa21b3f2957a39087abf/raw/9cb338b28d041092391acd78e451a45d31a1917e/broadcast_calc.sh
# @description
#   Takes the output from the function tonum and converts it to a network address
#   then setting the result as a varible.
#
# @arg $1 number returned by tonum
# @arg $2 variable to set the result to
#
# @example
# toaddr $NETMASKNUM NETMASK
#
# @stdout Returns a valid network address
function toaddr () {
    b1=$(( ($1 & 0xFF000000) >> 24))
    b2=$(( ($1 & 0xFF0000) >> 16))
    b3=$(( ($1 & 0xFF00) >> 8))
    b4=$(( $1 & 0xFF ))

    ## the echo exist to resolv SC2034
    echo "$b1 $b2 $b3 $b4" >/dev/null
    eval "$2=\$b1.\$b2.\$b3.\$b4"
}

# @description
#   Performs bitwise operation on each octet by it's host bit lenght adding each
#   result for the total. 
#
# @arg $1 the ip address or netmask
# @arg $2 the variable to store the result it   
#
# @example
# tonum $IPADDR IPADDRNUM
# tonum $NETMASK NETMASKNUM
#
# @stdout The bitwise number for the specefied network info
tonum() {
    if [[ $1 =~ ([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+) ]]; then
        # shellcheck disable=SC2034 #addr var is valid
        addr=$(( (${BASH_REMATCH[1]} << 24) + (${BASH_REMATCH[2]} << 16) + (${BASH_REMATCH[3]} << 8) + ${BASH_REMATCH[4]} ))
        eval "$2=\$addr"
    fi
}

# @description
#  Returns the broadcast, netmask and network for a given ip address and netmask.
#
# @arg $1 ipinfo Accepts either ip/cidr or ip/mask
#
# @example 
# return_netmask_ipaddr 192.168.2.11/24
# return_netmask_ipaddr 192.168.2.11 255.255.255.0
function return_netmask_ipaddr () {
    if [[ $1 =~ ^([0-9\.]+)/([0-9]+)$ ]]; then
        # CIDR notation
        IPADDR=${BASH_REMATCH[1]}
        NETMASKLEN=${BASH_REMATCH[2]}
        zeros=$((32-NETMASKLEN))
        NETMASKNUM=0
        for (( i=0; i<zeros; i++ )); do
            NETMASKNUM=$(( (NETMASKNUM << 1) ^ 1 ))
        done
        NETMASKNUM=$((NETMASKNUM ^ 0xFFFFFFFF))
        toaddr $NETMASKNUM NETMASK
    else
        if [ "A${1}" == "A" ]
        then
            echo "No ip address info found."
            echo "Could not determine your primary network interface"
            echo "ip address and netamsk"
            exit 1
        fi
   
        IPADDR=${1}
        NETMASK=${2}
    fi

    # Split the ip address in the format of ip/cidr_mas or ip/netmask
    tonum "$IPADDR" IPADDRNUM
    tonum "$NETMASK" NETMASKNUM

    INVNETMASKNUM=$(( 0xFFFFFFFF ^ NETMASKNUM ))
    NETWORKNUM=$(( IPADDRNUM & NETMASKNUM ))
    BROADCASTNUM=$(( INVNETMASKNUM | NETWORKNUM ))

    # Return the ip address/mask network
    toaddr "$NETWORKNUM" NETWORK

    # Return the ip address/mask broadcast
    toaddr $BROADCASTNUM BROADCAST
}

##---------------------------------------------------------------------
## Get network information
##---------------------------------------------------------------------
# @description
# Discover which interface provides internet access and use that as the
# default network interface. Determines the follow info about the interface.
# * network device name
# * ip address
# * gateway
# * network
# * mac address
# * pointer record (ptr) notation for the ip address
function discover_host_networking () {
    ## Default Vars
    netdevice="${NETWORK_DEVICE:-none}"
    ipaddress="${IPADDRESS:-none}"
    gateway="${GATEWAY:-none}"
    network="${NETWORK:-none}"
    macaddr="${MACADDR:-none}"
    netmask="${HOST_NETMASK:-none}"
    reverse_zone="${REVERSE_ZONE:-none}"
    confirm_networking="${CONFIRM_NETWORKING:-yes}"
    confirm_libvirt_network="${CONFIRM_LIBVIRT_NETWORK:-yes}"

    ## Get all interfaces except wireless and bridge
    declare -a INTERFACES=()
    mapfile -t INTERFACES < <(ip link | \
	    awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}'|\
	    sed -e 's/^[[:space:]]*//')
    # shellcheck disable=SC2034 
    ALL_INTERFACES="${INTERFACES[*]}"

    ## Get primary network device
    ## Get ipaddress, netmask, netmask cidr prefix
    if [ "A${netdevice}" == "Anone" ]
    then
        netdevice=$(ip route get 8.8.8.8 | awk -- '{printf $5}')
    fi

    IPADDR_NETMASK=$(ip -o -f inet addr show "$netdevice" | awk '/scope global/ {print $4}')
    # shellcheck disable=SC2034 
    NETMASK_PREFIX=$(echo "$IPADDR_NETMASK" | awk -F'/' '{print $2}')
    ## Return netmask and ipaddress
    return_netmask_ipaddr "$IPADDR_NETMASK"

    ## Set ipaddress varaible
    #if [ "A${ipaddress}" == "Anone" ]
    #then
        ipaddress="${IPADDR}"
    #fi

    ## Set netmask address
    #if [ "A${netmask}" == "Anone" ]
    #then
        netmask="${NETMASK}"
    #fi

    ## set gateway
    #if [ "A${gateway}" == "Anone" ]
    #then
        gateway=$(ip route | grep "$netdevice" | awk '{print $3; exit}')
        #gateway=$(ip route get 8.8.8.8 | awk -F"via " 'NR==1{split($2,a," ");print a[1]}')
    #fi

    ## network 
    #if [ "A${network}" == "Anone" ]
    #then
        network="$(ipcalc -n "$IPADDR_NETMASK" | awk -F= '{print $2}')"
    #fi

    ## reverse zone
    #if [ "A${reverse_zone}" == "Anone" ]
    #then
        reverse_zone=$(echo "$network" | awk -F . '{print $4"."$3"."$2"."$1".in-addr.arpa"}'| sed 's/^[^.]*.//g')
    #fi

    ## mac address
    #if [ "A${macaddr}" == "Anone" ]
    #then
        macaddr=$(ip addr show "$netdevice" | grep link | awk '{print $2}' | head -1)
    #fi

    get_primary_interface_status="interface_done"
    BASELINE_STATUS+=("$get_primary_interface_status")

    ## Export vars for updating qubinode_vars.txt
    export CONFIRM_NETWORKING="${confirm_networking:-yes}"
    export NETWORK_DEVICE="${netdevice:-none}"
    export IPADDRESS="${ipaddress:-none}"
    export GATEWAY="${gateway:-none}"
    export NETMASK="${netmask:-none}"
    export MACADDR="${macaddr:-none}"
    export NETWORK="${network:-none}"
    export REVERSE_ZONE="${reverse_zone:-none}"
    export CONFIRM_LIBVIRT_NETWORK="${confirm_libvirt_network:-yes}"
}

# @description
# Runs the functions discover_host_networking, libvirt_network_info and verify_networking_info
function setup_networking () {
 
    discover_host_networking

    ## Libvirt Network
    if [ "A${confirm_libvirt_network}" == "Ayes" ]
    then
        libvirt_network_info
    fi

    ## Verify network interface details
    if [ "A${confirm_networking}" == "Ayes" ]
    then
        verify_networking_info
    fi
}

# @description
# Give user the choice of creating a NAT or Bridge libvirt network or to use
# an existing libvirt network.
# 
function libvirt_network_info () {

    ## defaults
    libvirt_network_name="${LIBVIRT_NETWORK_NAME:-default}"
    libvirt_bridge_name="${LIBVIRT_BRIDGE_NAME:-qubibr0}"
    create_libvirt_bridge="${CREATE_LIBVIRT_BRIDGE:-yes}"
    confirm_libvirt_network="${CONFIRM_LIBVIRT_NETWORK:-yes}"
        
    local libvirt_net_choices
    local libvirt_net_choice
    local libvirt_net_selections
    local libvirt_net_msg
    libvirt_net_selections="Skip Specify Continue"
    IFS=" " read -r -a libvirt_net_choices <<< "$libvirt_net_selections"
    libvirt_net_msg=" Would you like to ${cyn:?}skip${end:?} or ${cyn:?}continue${end:?} the bridge network setup or ${cyn:?}specify${end:?} a libvirt network to use?"

    echo "confirm_libvirt_network=$confirm_libvirt_network"
    if [ "${confirm_libvirt_network}" == 'yes' ]
    then
        printf "%s\n\n" ""
        printf "%s\n" "  ${blu:?}Networking Details${end:?}"
        printf "%s\n" "  ${blu:?}***********************************************************${end:?}"
        printf "%s\n" "  The default libvirt network name is a nat network called: ${cyn:?}${libvirt_network_name}${end:?}."
        printf "%s\n\n" "  A bridge libvirt network is created to make it easy to access"
        printf "%s\n" "  Choose ${cyn:?}Skip${end:?} if your libvirt network ${cyn:?}${libvirt_network_name}${end:?} is already configured"
        printf "%s\n" "  as a bridged network."
        printf "%s\n" "  Choose ${cyn:?}Specify${end:?} to enter the name of an existing"
        printf "%s\n" "  libvirt network you would like to use."
        printf "%s\n" "  Choose ${cyn:?}Continue${end:?} to proceed with creating a libvirt bridge network."
     
        confirm_menu_option "${libvirt_net_choices[*]}" "$libvirt_net_msg" libvirt_net_choice
        if [ "A${libvirt_net_choice}" == "ASpecify" ]
        then
            confirm_correct "Type the name of a existing libvirt network you would like to use" libvirt_network_name
            create_libvirt_bridge=no
	        confirm "  Is this a bridge network? ${cyn:?}yes/no${end:?}"
            if [ "A${response}" == "Ayes" ]
            then
	            libvirt_bridge_name="${libvirt_network_name}"
                confirm_libvirt_network=no
	        fi
        elif [ "A${libvirt_net_choice}" == "ASkip" ]
        then
            create_libvirt_bridge=no
            printf "%s\n" "  Using the libvirt nat network called: ${cyn:?}${libvirt_network_name}${end:?}."
            confirm_libvirt_network=no
        else
            export create_libvirt_bridge="yes"
            
            confirm_libvirt_network=no
        fi
    fi
    verify_networking_info

    ## Export vars for updating qubinode-vars.txt
    export CREATE_LIBVIRT_BRIDGE="${create_libvirt_bridge:-yes}"
    export LIBVIRT_NETWORK_NAME="${libvirt_network_name:-default}"
    export LIBVIRT_BRIDGE_NAME="${libvirt_bridge_name:-qubibr0}"
}

# @description
# Asks user to confirm discovered network information.
# 
# @see discover_host_networking
function verify_networking_info () {
    printf "%s\n\n" "  The below networking information was discovered and will be used for creating a bridge NETWORK."
    printf "%s\n" "  ${blu:?}NETWORK_DEVICE${end:?}=${cyn:?}${NETWORK_DEVICE:?}${end:?}"
    printf "%s\n" "  ${blu:?}IPADDRESS${end:?}=${cyn:?}${IPADDRESS:?}${end:?}"
    printf "%s\n" "  ${blu:?}GATEWAY${end:?}=${cyn:?}${GATEWAY:?}${end:?}"
    printf "%s\n" "  ${blu:?}NETMASK${end:?}=${cyn:?}${NETMASK:?}${end:?}"
    printf "%s\n" "  ${blu:?}NETWORK${end:?}=${cyn:?}${NETWORK:?}${end:?}"
    printf "%s\n\n" "  ${blu:?}MACADDR${end:?}=${cyn:?}${MACADDR:?}${end:?}"

    confirm "  Do you want to change any of the above? ${cyn:?}yes/no${end:?}"
    if [ "A${response}" == "Ayes" ]
    then
        printf "%s\n\n" "  ${blu:?}Choose a attribute to change: ${end:?}"
        tmp_file=$(mktemp)
        while true
        do
            discover_host_networking
            networking_opts=("NETWORK_DEVICE - ${cyn:?}${NETWORK_DEVICE:?}${end:?}" \
                             "IPADDRESS - ${cyn:?}${IPADDRESS:?}${end:?}" \
                             "GATEWAY   - ${cyn:?}${GATEWAY:?}${end:?}" \
                             "NETWORK   - ${cyn:?}${NETWORK:?}${end:?}" \
                             "NETMASK   - ${cyn:?}${NETMASK:?}${end:?}" \
                             "MACADDR   - ${cyn:?}${MACADDR:?}${end:?}" \
                             "Reset     - Revert changes" \
                             "Save      - Save changes")
            createmenu "${networking_opts[@]}"
            result=$(echo "${selected_option}"| awk '{print $1}')
            case $result in
                NETWORK_DEVICE)
            	    echo "NETWORK_DEVICE=$NETWORK_DEVICE" >> "$tmp_file"
                    confirm_correct "Enter the NETWORK interface" NETWORK_DEVICE
                    ;;
                IPADDRESS)
            	    echo "IPADDRESS=$IPADDRESS" >> "$tmp_file"
                    confirm_correct "Enter ip address to assign to ${NETWORK_DEVICE}" IPADDRESS
                    ;;
                GATEWAY)
            	    echo "GATEWAY=$GATEWAY" >> "$tmp_file"
                    confirm_correct "Enter GATEWAY address to assign to ${NETWORK_DEVICE}" GATEWAY
                    ;;
                NETWORK)
            	    echo "NETWORK=$NETWORK" >> "$tmp_file"
                    confirm_correct "Enter the NETMASK cidr for ip ${IPADDRESS}" NETWORK
                    ;;
                MACADDR)
            	    echo "MACADDR=$MACADDR" >> "$tmp_file"
                    confirm_correct "Enter the mac address assocaited with ${NETWORK_DEVICE}" MACADDR
                    ;;
                Reset)
		    # shellcheck disable=SC1091
		    # shellcheck source="$tmp_file"
            	    source "$tmp_file"
            	    echo > "$tmp_file"
                    ;;
                Save) 
                    confirm_networking=no
                    break
            	;;
                * ) 
                    echo "Please answer a valid choice"
            	;;
            esac
        
        done
    else
        confirm_networking=no
    fi
}

##---------------------------------------------------------------------
## Check for RHSM registration
##---------------------------------------------------------------------
# @description
# Determine if host is RHEL and sets the vars:
# * rhel_release
# * rhel_major
# * os_name
#
function pre_os_check() {
    if grep -q 'Red Hat Enterprise Linux' /etc/redhat-release
    then
        # shellcheck disable=SC2034
        rhel_version=$(< /etc/redhat-release grep -o "[7-8].[0-9]")
        rhel_major=$(sed -rn 's/.*([0-9])\.[0-9].*/\1/p' /etc/redhat-release)
        rhel_release="${rhel_major}"
        rhel_minor=$(echo "$rhel_version" |cut -d. -f2)
        # shellcheck disable=SC2034
        
        discovered_os_name=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
        if [ "A${discovered_os_name}" == 'A"Red Hat Enterprise Linux"' ]
        then
            discovered_os_name="rhel"
        fi
        os_name="${OS_NAME:-$discovered_os_name}"

        RHSM_SYSTEM=yes
    
        ## Export vars for updating qubinode_vars.txt
        rhsm_system="$RHSM_SYSTEM"
        export RHEL_RELEASE="$rhel_release"
        export RHEL_MAJOR="$rhel_major"
        export RHEL_MINOR="$rhel_minor"
        export RHEL_VERSION="$rhel_version"
        export OS_NAME="$os_name"
        export RHSM_SYSTEM="$RHSM_SYSTEM"
    fi
}

# @description
# If host is RHEL, verify subcription-manager command is available.
# Exists the installer if subscription-manager not found.
# If subscription-manager is found, determine if the host is registered to Red Hat.
function check_rhsm_status () {
    if [ "A${os_name}" == 'Arhel' ]
    then
        RHSM_SYSTEM=yes
        if ! which subscription-manager > /dev/null 2>&1
        then
            printf "%s\n" ""
            printf "%s\n" " ${red:?}Error: subcription-manager command not found.${end:?}"
            printf "%s\n" " ${red:?}The subscription-manager command is required.${end:?}"
	        exit 1
	    fi
    fi    
    ## define message var
    local system_registered_msg
    system_registered_msg="$(hostname) is registered to Red Hat"
    if [ "A${RHSM_SYSTEM-}" == 'Ayes' ]
    then
        printf "%s\n" ""
        printf "%s\n" "  ${blu:?}Confirming System Registration Status${end:?}"
        printf "%s\n" "  ${blu:?}***********************************************************${end:?}"
	    if sudo subscription-manager status | grep -q 'Overall Status: Current'
        then
	        SYSTEM_REGISTERED=yes
	    else
	        SYSTEM_REGISTERED=no
	        system_registered_msg="$(hostname) is not registered to Red Hat"
        fi
    fi
    printf "%s\n" "  ${yel:?}${system_registered_msg}${end:?}"
}

# @description
# Deteremine if the registered RHEL host is has a subscription attached to it.
function verify_rhsm_status () {

   ## Ensure the system is registered
   sudo subscription-manager identity > /dev/null 2>&1
   sub_identity_status="$?"
   if [ "A${sub_identity_status}" == "A1" ]
   then
       ## Register system to Red Hat
       register_system
   fi

   ## Ensure the system status is current
   status_result=$(mktemp)
   # shellcheck disable=SC2024
   sudo subscription-manager status > "${status_result}" 2>&1
   sub_status=$(awk -F: '/Overall Status:/ {print $2}' "${status_result}"|sed 's/^ *//g')
   if [ "A${sub_status}" != "ACurrent" ]
   then
       sudo subscription-manager refresh > /dev/null 2>&1
       sudo subscription-manager attach --auto > /dev/null 2>&1
   fi

   #check again
   # shellcheck disable=SC2024
   sudo subscription-manager status > "${status_result}" 2>&1
   status=$(awk -F: '/Overall Status:/ {print $2}' "${status_result}"|sed 's/^ *//g')
   if [ "A${status}" != "ACurrent" ]
   then
       printf "%s\n" " ${red:?}Cannot determine the subscription status of ${end:?}${cyn:?}$(hostname)${end:?}"
       printf "%s\n" " ${red:?}Error details are:${end:?} "
       cat "${status_result}"
       printf "%s\n\n" " Please resolved and try again"
       exit 1
   else
       printf "%s\n\n" "  ${yel:?}Successfully registered $(hostname) to RHSM${end:?}"
   fi
}

# @description
# Register the RHEL host to Red Hat
function register_system () {
    ## set default rhsm system
    rhsm_system="${RHSM_SYSTEM:-no}"
    system_registered="${SYSTEM_REGISTERED:-no}"

    if [ "${rhsm_system}" == "none" ]
    then
        pre_os_check
        rhsm_system="${RHSM_SYSTEM:-no}"
    fi

    if [ "${system_registered}" == "no" ]
    then
        check_rhsm_status
        system_registered="${SYSTEM_REGISTERED:-no}"
    fi

    if [ "A${rhsm_system}" == "Ayes" ] && [ "A${system_registered}" == "Ano" ]
    then
        printf "%s\n\n" ""
        printf "%s\n" "  ${blu:?}RHSM Registration${end:?}"
        printf "%s\n" "  ${blu:?}***********************************************************${end:?}"
        rhsm_reg_result=$(mktemp)
        echo sudo subscription-manager register \
    	      "${RHSM_CMD_OPTS}" --force \
    	      --release="'${RHEL_RELEASE-}'"|\
    	      sh > "${rhsm_reg_result}" 2>&1
        RESULT="$?"
        if [ ${RESULT} -eq 0 ]
        then
            verify_rhsm_status
	        SYSTEM_REGISTERED="yes"
    	else
    	    printf "%s\n" " ${red:?}$(hostname) registration to RHSM was unsuccessfull.${end:?}"
            cat "${rhsm_reg_result}"
	        exit 1
        fi
    fi
    register_system_status="register_done"
    BASELINE_STATUS+=("$register_system_status")
}


##---------------------------------------------------------------------
## Get User Input
##---------------------------------------------------------------------
# @description
# Ask user to confirm input.
function confirm_menu_option () 
{
    entry_is_correct=""
    local __input_array="$1"
    local __input_question=$2
    local __resultvar="$3"
    local data_array
    IFS=" " read -r -a data_array <<< "$__input_array"
    #mapfile -t data_array <<< $__input_array
    #data_array=( "$__input_array" )

    while [[ "${entry_is_correct}" != "yes" ]];
    do
        ## Get input from user
	printf "%s\n" " ${__input_question}"
        createmenu "${data_array[@]}"
        user_choice=$(echo "${selected_option}"|awk '{print $1}')
        if [[ "$__resultvar" ]]; then
	    result="'$user_choice'"
            eval "$__resultvar"="$result"
            #eval "$__resultvar"="'$user_choice'"
        else
            echo "$user_choice"
        fi

        read -r -p "  You entered ${cyn:?}$user_choice${end:?}, is this correct? ${cyn:?}yes/no${end:?} " response
        if [[ $response =~ ^([yy][ee][ss]|[yy])$ ]]
        then
            entry_is_correct="yes"
        fi
    done
}

# @description
# Confirm with user if they want to continue with a given input or choice.
function confirm () {
    continue=""
    while [[ "${continue}" != "yes" ]];
    do
        read -r -p "${1:-are you sure yes or no?} " response
        if [[ $response =~ ^([yy][ee][ss]|[yy])$ ]]
        then
            response="yes"
            continue="yes"
        elif [[ $response =~ ^([nn][oo])$ ]]
        then
            #echo "you choose $response"
            response="no"
            continue="yes"
        else
            printf "%s\n" " ${blu:?}try again!${end:?}"
        fi
    done
}

# @description
# Accepts input from user and return what the users input.
function accept_user_input ()
{
    local __questionvar="$1"
    local __resultvar="$2"
    echo -n "  ${__questionvar} and press ${cyn:?}[ENTER]${end:?}: "
    read -r input_from_user
    local output_data="$input_from_user"
    local result

    if [[ "$__resultvar" ]]; then
	result="'$output_data'"
        eval "$__resultvar"="$result"
        #eval "$__resultvar"="'$output_data'"
    else
        echo "$output_data"
    fi
}

# @description
# Confirms if the user input is correct.
function confirm_correct () {
    entry_is_correct=""
    local __user_question=$1
    local __resultvar=$2
    user_input_data=""
    local result

    while [[ "${entry_is_correct}" != "yes" ]];
    do
	## Get input from user
        accept_user_input "$__user_question" user_input_data
        if [[ "$__resultvar" ]]; then
	    result="'$user_input_data'"
            eval "$__resultvar"="$result"
            #eval "$__resultvar"="'$user_input_data'"
        else
            echo "$user_input_data"
        fi

	read -r -p "  You entered ${cyn:?}$user_input_data${end:?}, is this correct? ${cyn:?}yes/no${end:?} " response
        if [[ $response =~ ^([yy][ee][ss]|[yy])$ ]]
        then
            entry_is_correct="yes"
	fi
    done
}

# @description
# A generic user choice menu used to provide user with choice.
function createmenu () {
    select selected_option; do # in "$@" is the default
        if ! [[ "$REPLY" =~ ^[0-9]+$ ]]
        then 
	    REPLY=80
        fi
        if [ $REPLY -eq $REPLY ]
        #if [ $REPLY -eq $REPLY 2>/dev/null ]
        then
            if [ 1 -le "$REPLY" ] && [ "$REPLY" -le $(($#)) ]; then
                break;
            else
                echo "    ${blu:?}Please make a vaild selection (1-$#).${end:?}"
            fi
         else
            echo "    ${blu:?}Please make a vaild selection (1-$#).${end:?}"
         fi
    done
}

# @description
# Outputs asterisks when sensitive data is entered by the user.
function read_sensitive_data () {
    # based on shorturl.at/BEHY3
    sensitive_data=''
    while IFS= read -r -s -n1 char; do
      [[ -z $char ]] && { printf '\n'; break; } # ENTER pressed; output \n and break.
      if [[ $char == $'\x7f' ]]; then # backspace was pressed
          # Remove last char from output variable.
          [[ -n $sensitive_data ]] && sensitive_data=${sensitive_data%?}
          # Erase '*' to the left.
          printf '\b \b'
      else
        # Add typed char to output variable.
        sensitive_data+=$char
        # Print '*' in its stead.
        printf '*'
      fi
    done
}

# @description
# Load qubinode vars from qubinode_vars.txt
load_qubinode_vars () {
    local _vars_file
    
    if [ -f "$QUBINODE_BASH_VARS" ]
    then
        _vars_file="${QUBINODE_BASH_VARS}"
    else
        _vars_file="${QUBINODE_BASH_VARS_TEMPLATE}"
    fi
    set -o allexport
    # shellcheck disable=SC1091
    # shellcheck source=playbooks/vars/qubinode_vars.yml
    source "$_vars_file"
    set +o allexport
}

# @description
# Read variables from ansible encrupted vault file.
function load_vault_vars () 
{
    vault_parse_cmd="cat"
    if which ansible-vault >/dev/null 2>&1
    then
        if ansible-vault view "${VAULT_FILE}" >/dev/null 2>&1
        then
	        vault_parse_cmd="ansible-vault view"
	    fi
    fi

    if [ -f "${VAULT_FILE}" ]
    then
        RHSM_USERNAME=$($vault_parse_cmd "${VAULT_FILE}" | awk '/^rhsm_username:/ {print $2}')
        RHSM_PASSWORD=$($vault_parse_cmd "${VAULT_FILE}" | awk '/^rhsm_password:/ {print $2}')
        RHSM_ORG=$($vault_parse_cmd "${VAULT_FILE}" | awk '/^rhsm_org:/ {print $2}')
        RHSM_ACTKEY=$($vault_parse_cmd "${VAULT_FILE}" | awk '/^rhsm_activationkey:/ {print $2}')
        ADMIN_USER_PASSWORD=$($vault_parse_cmd "${VAULT_FILE}" | awk '/^admin_user_password:/ {print $2}')

	    # shellcheck disable=SC2034 # used when vault file is generated
        IDM_DM_PASS=$($vault_parse_cmd "${VAULT_FILE}" | awk '/^idm_dm_pwd:/ {print $2}')
        IDM_ADMIN_PASS=$($vault_parse_cmd "${VAULT_FILE}" | awk '/^idm_admin_pwd:/ {print $2}')
	
	    # shellcheck disable=SC2034 # used when vault file is generated
        TOWER_PG_PASS=$($vault_parse_cmd "${VAULT_FILE}" | awk '/^tower_pg_password:/ {print $2}')
        
	    # shellcheck disable=SC2034 # used when vault file is generated
	    TOWER_MQ_PASS=$($vault_parse_cmd "${VAULT_FILE}" | awk '/^tower_rabbitmq_password:/ {print $2}')
        #IDM_USER_PASS=$($vault_parse_cmd "${VAULT_FILE}" | awk '/^idm_admin_pwd:/ {print $2}')
    fi
}

# @description
# Ask the user if they want to register the host to Red Hat using username/password or activationkey/org-id.
function rhsm_get_reg_method () {
    local user_response
    printf "%s\n\n" ""
    printf "%s\n" "  ${blu:?}Red Hat Subscription Registration${end:?}"
    printf "%s\n" "  ${blu:?}****************************************************************************${end:?}"

    printf "%s\n" "  The goal of the qubinode-installer is to automate the installation of"
    printf "%s\n" "  supported Red Hat products. To provide this experience we ask for a method"
    printf "%s\n" "  to register your Red Hat product and current system to the Red Hat Customer"
    printf "%s\n\n" "  portal."
    printf "%s\n" "  You can skip this step if your system is already registered and you are not"
    printf "%s\n\n" "  interested in using the installer to deploy any Red Hat product."
    confirm "  Continue with providing a method to register to Red Hat? ${blu:?}yes/no${end:?}"
    if [ "A${response}" == "Ayes" ]
    then
        printf "%s\n" ""
        printf "%s\n" "  The two available methods are:"
        printf "%s\n" "     option 1: ${cyn:?}activation key${end:?}"
	    printf "%s\n\n" "     option 2: ${cyn:?}username/password${end:?} (most common)"
        printf "%s\n" "  Which method would you like to use?"
        rhsm_msg=("Activation Key" "Username and Password")
        createmenu "${rhsm_msg[@]}"
        user_response="${selected_option}"
        RHSM_REG_METHOD=$(echo "${user_response}"|awk '{print $1}')
    else
        check_rhsm_status
        if [ "${SYSTEM_REGISTERED}" == "no" ]
        then
            printf "%s\n" "  Please register your system and run the installer again."
	        exit 1
        fi
        RHSM_REG_METHOD="skip"
    fi
}

# @description
# Takes in senstive input from user.
function accept_sensitive_input () {
    printf "%s\n" ""
    printf "%s\n" "  Try not to ${cyn:?}Backspace${end:?} to correct a typo, "
    printf "%s\n\n" "  you will be prompted again if the input does not match."
    while true
    do
        printf "%s" "  $MSG_ONE"
        read_sensitive_data
        USER_INPUT1="${sensitive_data}"
        printf "%s" "  $MSG_TWO"
        read_sensitive_data
        USER_INPUT2="${sensitive_data}"
        if [ "$USER_INPUT1" == "$USER_INPUT2" ] 
        then
	    sensitive_data="$USER_INPUT2"
	    break
	fi
        printf "%s\n"  "  ${cyn:?}Please try again${end:?}: "
        printf "%s\n" ""
    done
}

# @description
# Ask user for credentials to register system to Red Hat.        
function rhsm_credentials_prompt () {

    rhsm_reg_method="${RHSM_REG_METHOD:-none}"
    rhsm_username="${RHSM_USERNAME:-none}"
    rhsm_password="${RHSM_PASSWORD:-none}"
    rhsm_org="${RHSM_ORG:-none}"
    rhsm_actkey="${RHSM_ACTKEY:-none}"
    if [ "A${rhsm_reg_method}" == "AUsername" ]
    then
        if [ "A${rhsm_username}" == "Anone" ]
        then
            printf "%s\n" ""
	        confirm_correct "Enter your RHSM username and press" RHSM_USERNAME
        fi

        if [ "A${rhsm_password}" == 'Anone' ]
        then
	        MSG_ONE="Enter your RHSM password and press ${cyn:?}[ENTER]${end:?}:"
            MSG_TWO="Enter your RHSM password password again ${cyn:?}[ENTER]${end:?}:"
	        accept_sensitive_input
            RHSM_PASSWORD="${sensitive_data}"
        fi

	    ## set registration argument
	    RHSM_CMD_OPTS="--username=${RHSM_USERNAME} --password=${RHSM_PASSWORD}"
    fi

    if [ "A${rhsm_reg_method}" == "AActivation" ]
    then
        if [ "A${rhsm_org}" == 'Anone' ]
        then
            printf "%s\n" ""
            printf "%s\n\n" "Your RHSM org ID is saved in ${project_dir}/playbooks/vars/qubinode_vault.yml."
	        MSG_ONE="Enter your RHSM org id and press ${cyn:?}[ENTER]${end:?}:"
            MSG_TWO="Enter your RHSM org id again ${cyn:?}[ENTER]${end:?}:"
	        accept_sensitive_input
            RHSM_ORG="${sensitive_data}"
        fi

        if [ "A${rhsm_actkey}" == 'Anone' ]
        then
	       confirm_correct "Enter your RHSM activation key" RHSM_ACTKEY
        fi

	    ## Set registration argument
	    RHSM_CMD_OPTS="--org=${RHSM_ORG} --activationkey=${RHSM_ACTKEY}"
    fi
}

# @description
# This is a wrapper to call functions rhsm_get_reg_method and rhsm_credentials_prompt.
function ask_user_for_rhsm_credentials () {
    rhsm_reg_method="${RHSM_REG_METHOD:-none}"

    if [ "A${rhsm_reg_method}" == "Anone" ]
    then
	    rhsm_get_reg_method
        rhsm_credentials_prompt
    else
        rhsm_credentials_prompt
    fi
}

# @description
# Ask the user for their password.
function ask_for_admin_user_pass () {
    admin_user_password="${ADMIN_USER_PASSWORD:-none}"
    # root user password to be set for virtual instances created
    if [ "A${admin_user_password}" == "Anone" ]
    then
        printf "%s\n\n" ""
        printf "%s\n" " ${blu:?} Admin User Credentials${end:?}"
	    printf "%s\n" "  ${blu:?}***********************************************************${end:?}"
        printf "%s\n" "  Your password for your username ${cyn:?}${QUBINODE_ADMIN_USER}${end:?} is needed to allow"
        printf "%s\n" "  the installer to setup password-less sudoers. Your password"
        printf "%s\n" "  and other secrets will be stored in a encrypted ansible vault file"
	    printf "%s\n\n" "  ${cyn:?}${project_dir}/playbooks/vars/qubinode_vault.yml${end:?}."
        printf "%s\n" "  You can view this file by executing: "
        printf "%s\n\n" "  ${cyn:?}ansible-vault ${project_dir}/playbooks/vars/qubinode_vault.yml ${end:?}"

        MSG_ONE="Enter a password for ${cyn:?}${QUBINODE_ADMIN_USER}${end:?} ${blu:?}[ENTER]${end:?}:"
        MSG_TWO="Enter a password again for ${cyn:?}${QUBINODE_ADMIN_USER}${end:?} ${blu:?}[ENTER]${end:?}:"
        accept_sensitive_input
        admin_user_password="$sensitive_data"
        export ADMIN_USER_PASSWORD="${admin_user_password:-none}"
    fi
}

# @description
# If multiple disk devices are found on the kvm host, ask the user if they
# would like to dedicate a disk device for /var/lib/libivrt/images.
function check_additional_storage () {
    getPrimaryDisk
    create_libvirt_lvm="${CREATE_LIBVIRT_STORAGE:-yes}"
    libvirt_pool_disk="${LIBVIRT_POOL_DISK:-none}"
    libvirt_dir_verify="${LIBVIRT_DIR_VERIFY:-none}"
    libvirt_dir="${LIBVIRT_DIR:-/var/lib/libvirt/images}"
    LIBVIRT_DIR="${LIBVIRT_DIR:-$libvirt_dir}"

    libvirt_pool_name="${LIBVIRT_DIR_POOL_NAME:-default}"
    # confirm directory for libvirt images
    if [ "A${libvirt_dir_verify}" != "Ano" ]
    then
        printf "%s\n\n" ""
        printf "%s\n" "  ${blu:?}Location for Libvirt directory Pool${end:?}"
        printf "%s\n" "  ${blu:?}***********************************************************${end:?}"
        printf "%s\n" "  The current path is set to ${cyn:?}$libvirt_dir${end:?}."
        confirm "  Do you want to change it? ${blu:?}yes/no${end:?}"
        if [ "A${response}" == "Ayes" ]
        then
	        confirm_correct "Enter a new path" LIBVIRT_DIR
            #TODO: confirm new path exist, if not exist ask user if it should be created.
	    fi
        printf "%s\n" "  The default libvirt dir pool name is ${cyn:?}$libvirt_pool_name${end:?}."
        confirm "  Do you want to change it? ${blu:?}yes/no${end:?}"
        if [ "A${response}" == "Ayes" ]
        then
	        confirm_correct "Enter the name of the libvirt dir pool you would like to use" libvirt_pool_name
	    fi
        libvirt_dir_verify=no
    fi

    if [[ "A${create_libvirt_lvm}" == "Ayes" ]] && [[ "A${libvirt_pool_disk}" == "Anone" ]]
    then
	    local AVAILABLE_DISKS
	    IFS=" " read -r -a AVAILABLE_DISKS <<< "$ALL_DISK"
        if [ ${#AVAILABLE_DISKS[@]} -gt 1 ]
        then

            printf "%s\n\n" ""
            printf "%s\n" "  ${blu:?}Dedicated Storage Device For Libvirt Directory Pool${end:?}"
            printf "%s\n" "  ${blu:?}***********************************************************${end:?}"
            printf "%s\n" "  Multiple storage devices are found, you can dedicate one for"
            printf "%s\n" "  use exclusively with ${cyn:?}$LIBVIRT_DIR${end:?}. This is where"
            printf "%s\n" "  the virtual disk devices for all VM’s are stored.Please note that"
            printf "%s\n" "  this process wipes the storage device then creates a new volume"
            printf "%s\n" "  group and logical volume for use with ${cyn:?}$LIBVIRT_DIR${end:?}."
            printf "%s\n" ""
            printf "%s\n" "  Your primary storage device appears to be ${blu:?}${primary_disk}${end:?}."
            printf "%s\n\n" "  The following additional storage devices where found:"

            for disk in "${AVAILABLE_DISKS[@]}"
            do
                printf "%s\n" "     ${blu:?} * ${end:?}${blu:?}$disk${end:?}"
            done
        fi

        confirm "   Do you want to dedicate a storage device: ${blu:?}yes/no${end:?}"
        printf "%s\n" " "
        if [ "A${response}" == "Ayes" ]
        then
            disk_msg="Please select secondary disk to be used"
            confirm_menu_option "${AVAILABLE_DISKS[*]}" "$disk_msg" libvirt_pool_disk
            LIBVIRT_POOL_DISK="$libvirt_pool_disk"
            CREATE_LIBVIRT_STORAGE=yes
	        create_libvirt_lvm="$CREATE_LIBVIRT_STORAGE"
	    else
            LIBVIRT_POOL_DISK="none"
            CREATE_LIBVIRT_STORAGE=no
            create_libvirt_lvm="$CREATE_LIBVIRT_STORAGE"
        fi
    fi
    check_additional_storage_status="storage_done"
    BASELINE_STATUS+=("$check_additional_storage_status")

    ## Export vars for updating qubinode_vars.txt
    export LIBVIRT_DIR="${LIBVIRT_DIR-none}"
    export LIBVIRT_DIR_POOL_NAME="${libvirt_pool_name:-default}"
    export LIBVIRT_DIR_VERIFY="${libvirt_dir_verify:-none}"
}

# @description
# Ask user to set a password that will be used for the IdM server.
function ask_idm_password () {
    idm_admin_pass="${IDM_ADMIN_PASS:=none}"
    if [ "A${idm_admin_pass}" == "Anone" ]
    then
        printf "%s\n" ""
        MSG_ONE="Enter a password for the IdM server ${cyn:?}${idm_server_hostname}${end:?} ${blu:?}[ENTER]${end:?}:"
        MSG_TWO="Enter a password again for the IdM server ${cyn:?}${idm_server_hostname}${end:?} ${blu:?}[ENTER]${end:?}:"
        accept_sensitive_input
        # shellcheck disable=SC2034
        idm_admin_pwd="${sensitive_data}"
    fi
}

# @description
# Define a static ip address for the IdM server.
function set_idm_static_ip () {
    printf "%s\n" ""
    confirm_correct "$static_ip_msg" idm_server_ip
    if [ "A${idm_server_ip}" != "A" ]
    then
        printf "%s\n" "  The qubinode-installer will connect to the IdM server on ${cyn:?}$idm_server_ip${end:?}"
    fi
}

# @description
# Ask user to enter their dns zone name.
function ask_about_domain() {
    domain_tld="${DOMAIN_TLD:-lan}"
    generated_domain="${QUBINODE_ADMIN_USER}.${domain_tld}"
    domain="${DOMAIN:-$generated_domain}"
    confirmed_user_domain="${CONFIRM_USER_DOMAIN:-yes}"
    confirmation_question=null
    idm_deploy_method="${IDM_DEPLOY_METHOD:-none}"

    if [ "A${confirmed_user_domain}" == "Ayes" ]
    then
        printf "%s\n\n" ""
        printf "%s\n" "  ${blu:?}DNS Domain${end:?}"
        printf "%s\n" "  ${blu:?}***********************************************************${end:?}"

        if [[ "A${idm_deploy_method}" == "Ayes" ]]
        then
            confirmation_question="Enter your existing IdM server domain, e.g. example.com"
        else
            printf "%s\n" "  The domain ${cyn:?}${generated_domain}${end:?} was generated for you."
            confirm "  Do you want to change it? ${blu:?}yes/no${end:?}"
            if [ "A${response}" == "Ayes" ]
            then
                confirmation_question="Enter your domain name"
	        else
		        confirmed_user_domain=no
	        fi
        fi

        ## Ask user to confirm domain
        if [ "A${confirmation_question}" != "Anull" ]
        then
            confirm_correct "${confirmation_question}" USER_DOMAIN
            if [ "A${USER_DOMAIN}" != "A" ]
            then
	          domain="$USER_DOMAIN"
		      confirmed_user_domain=no
            fi
        fi
	
    fi
    ask_about_domain_status="domain_done"
    BASELINE_STATUS+=("$ask_about_domain_status")

    ## Export vars for updating qubinode_vars.txt
    export CONFIRM_USER_DOMAIN="${confirmed_user_domain:-yes}"
    export DOMAIN="${domain:-$generated_domain}"
}

# @description
# Gather the connection information from a existing IdM server.
function connect_existing_idm () {
    idm_hostname="${generated_idm_hostname:-none}"
    #idm_hostname="${idm_server_hostname:-none}"
    static_ip_msg=" Enter the ip address for the existing IdM server"
    allow_zone_overlap=no
    if [ "A${idm_hostname}" != "Anone" ]
    then
        printf "%s\n\n" ""
        printf "%s\n" "  Please provide the hostname of the existing IdM server."
        printf "%s\n\n" "  For example if you IdM server is ${cyn:?}dns01.lab.com${end:?}, you should enter ${blu:?}dns01${end:?}."
        local existing_msg="Enter the existing DNS server hostname"
	confirm_correct "${existing_msg}" idm_server_hostname

	## Get ip address for Idm server
	get_idm_server_ip

	## get_idm_admin_user
	get_idm_admin_user

	##get user password not working
	ask_idm_password
    fi
}

# @description
# Get the ip address for a existing IdM server.
function get_idm_server_ip () {
    if [ "A${idm_server_ip}" == "Anone" ]
    then
        set_idm_static_ip
    fi
}

# @description
# Get the admin username for a existing IdM server.
function get_idm_admin_user () {
    ## set idm_admin_user vars
    idm_admin_user="${IDM_ADMIN_USER:-admin}"
    idm_admin_existing_user="${IDM_EXISTING_ADMIN_USER:-none}"

    if [ "A${idm_admin_user}" == "Aadmin" ] && [ "A${idm_admin_existing_user}" == "Anone" ]
    then
        printf "%s\n\n" ""
        local admin_user_msg="What is the admin username for ${cyn:?}${idm_server_hostname}${end:?}?"
	    confirm_correct "$admin_user_msg" idm_admin_existing_user
	    idm_admin_user="$idm_admin_existing_user"
    fi

    ## Export vars for updating qubinode_vars.txt
    export IDM_ADMIN_USER="${idm_admin_user:-admin}"
    export IDM_EXISTING_ADMIN_USER="${idm_admin_existing_user:-none}"
}

# @description
# Gather data for IdM server deployment.
function ask_about_idm () {
    ## Default variables
    idm_server_ip="${IDM_SERVER_IP:-none}"
    allow_zone_overlap="${ALLOW_ZONE_OVERLAP:-none}"
    deploy_idm="${DEPLOY_IDM:-yes}"
    idm_deploy_method="${IDM_DEPLOY_METHOD:-none}"
    idm_choices="deploy existing"
    idm_hostname_prefix="${IDM_HOSTNAME_PREFIX:-idm01}"
    idm_server_hostname="${IDM_SERVER_HOSTNAME:-none}"
    name_prefix="${NAME_PREFIX:-qbn}"

    ## set hostname
    if [ "A${idm_server_hostname}" == "Anone" ]
    then
        generated_idm_hostname="${name_prefix}-${idm_hostname_prefix}"
	    idm_server_hostname="$generated_idm_hostname"
    fi

    ## Should IdM be deployed
    if [ "A${deploy_idm}" == "Ayes" ] && [ "A${idm_deploy_method}" == "Anone" ]
    then
        printf "%s\n" ""
        printf "%s\n" "  ${blu:?}Red Hat Identity Manager (IdM)${end:?}"
        printf "%s\n" "  ${blu:?}***********************************************************${end:?}"

	if [ "A${idm_deploy_method}" == "Anone" ]
	then
	    ## FOR FUTURE USE
            ##printf "%s\n" "  CoreDNS is deployed is the default DNS server deployed."
            ##printf "%s\n" "  If you would like to have access to LDAP, then you can deploy"
	    ##printf "%s\n" "  Red Hat Identity manager (IdM)"
            printf "%s\n" "  IdM is use as the dns server for all qubinode dns needs."
            printf "%s\n\n" "  The installer can ${cyn:?}deploy${end:?} a local IdM server or connect to an ${cyn:?}existing${end:?} IdM server."
            idm_msg="Do you want to ${cyn:?}deploy${end:?} a new IdM or connect to an ${cyn:?}existing${end:?}? "
            confirm_menu_option "${idm_choices}" "${idm_msg}" idm_deploy_method
        fi

	    ## check idm setup method
	    case "$idm_deploy_method" in
	        deploy)
	    	    deploy_new_idm
	            ;;
	        existing)
	    	    connect_existing_idm
	            ;;
	        *)
	    	    return
	    	;;
	    esac
    fi

    ask_about_idm_status="idm_done"
    BASELINE_STATUS+=("$ask_about_idm_status")

    ## Export vars for updating qubinode_vars.txt
    export IDM_HOSTNAME_PREFIX="${idm_hostname_prefix:-idm01}"
    export DEPLOY_IDM="${DEPLOY_IDM:-yes}"
    export IDM_SERVER_HOSTNAME="${idm_server_hostname:-none}"
    export ALLOW_ZONE_OVERLAP="${allow_zone_overlap:-none}"
    export IDM_SERVER_IP="${idm_server_ip:-none}"
    export IDM_DEPLOY_METHOD="${idm_deploy_method:-none}"
}

# @description
# Gather required info for deploying a new IdM server.
function deploy_new_idm () {
    if [ "A${idm_server_ip}" == "Anone" ]
    then
        printf "%s\n" ""
        printf "%s\n" "  The IdM server will be assigned a dynamic ip address from"
        printf "%s\n" "  your network. The ip address will be displayed after IdM"
        printf "%s\n" "  has been deployed. You should configure you router assign"
        printf "%s\n\n" "  the ip permanently to the IdM server."
        printf "%s\n\n" "  You can also just specefy the ip address now."
        confirm "  Would you like to assign a ip address to the IdM server? ${cyn:?}yes/no${end:?}"
        if [ "A${response}" == "Ayes" ]
        then
            static_ip_msg=" Enter the ip address you would like to assign to the IdM server"
            set_idm_static_ip
            #TODO: also display the IdM server mac address once it has been deployed
        fi
    fi

    if [ "A${allow_zone_overlap}" == "Anone" ]
    then
        printf "%s\n" ""
        printf "%s\n\n" " ${blu:?} You can safely choose no for this next question.${end:?}"
        printf "%s\n" "  Choose ${cyn:?}yes${end:?} if ${cyn:?}$domain${end:?} is already in use on your network."
        confirm "  Would you like to enable allow-zone-overlap? ${cyn:?}yes/no${end:?}"
        if [ "A${response}" == "Ayes" ]
        then
             allow_zone_overlap=yes
	    else
             allow_zone_overlap=no
        fi
   fi

}

##---------------------------------------------------------------------
## YUM, PIP packages and Ansible roles, collections
##---------------------------------------------------------------------

# @description
# Install required baseline packages
function install_packages () {
    ## set local vars from environment variables
    local rhsm_system="$RHSM_SYSTEM"
    local rhel_release="$RHEL_RELEASE"
    local rhel_major="$RHEL_MAJOR"
    local os_name="$OS_NAME"
    local python3_installed="$PYTHON3_INSTALLED"
    local ansible_installed="$ANSIBLE_INSTALLED"
    local python_packages="python3-lxml python3-libvirt python3-netaddr python3-pyyaml python36 python3-pip python3-dns python-podman-api"
    local tools_packages="ipcalc toolbox"
    local ansible_packages="ansible git"
    local podman_packages="podman python-podman-api"
    local all_rpm_packages="$podman_packages $ansible_packages $tools_packages $python_packages"
    local yum_packages="${YUM_PACKAGES:-$all_rpm_packages}"
    local _rhel8_repos="rhel-8-for-x86_64-baseos-rpms rhel-8-for-x86_64-appstream-rpms ansible-2-for-rhel-8-x86_64-rpms"
    local pip_packages="${PIP_PACKAGES:-yml2json}"
    local rhel8_repos="${RHEL8_REPOS:-$_rhel8_repos}"
    local yum_packages="${YUM_PACKAGES:-$yum_packages}"

    printf "%s\n" ""
    printf "%s\n" "  ${blu:?}Ensure required yum repos are enabled${end:?}"
    printf "%s\n" "  ${blu:?}***********************************************************${end:?}"
    # check if packages needs to be installed
    local enabled_repos
    local repos_needed
    enabled_repos=$(mktemp)
    sudo subscription-manager repos --list-enabled | awk '/Repo ID:/ {print $3}' > "$enabled_repos"
    for repo in $rhel8_repos
    do
        if ! grep -q $repo "$enabled_repos"
        then
	    repos_needed=yes
	    break
        fi
    done
    if [ "${repos_needed:-none}" == "yes" ]
    then
        printf "%s\n" "  The installer needs to ensure the below repos are enabled and available:"
        printf "%s\n\n" "  $rhel8_repos"
        confirm "  Do you want to continue? ${cyn:?}yes/no${end:?}"
        if [ "A${response}" == "Ano" ]
        then
            printf "%s\n" "  You can manually ensure the above repos are enabled and try again."
            exit 0
        else
            # check if packages needs to be installed
            for repo in $rhel8_repos
            do
                if ! grep -q $repo "$enabled_repos"
                then
                    if ! sudo subscription-manager repos --enable="$repo" > /dev/null 2>&1
                    then
                        printf "%s\n" "  ${red:?}Failed to enable "$repo"${end:?}"
                	    exit 1
                    fi
                fi
            done
        fi

    fi

   ## Install rpm and pip packages
    printf "%s\n" ""
    printf "%s\n" "  ${blu:?}Ensure required packages are installed${end:?}"
    printf "%s\n" "  ${blu:?}***********************************************************${end:?}"

   # check if packages needs to be installed
    local packages_needed
    for pkg in $yum_packages
    do
        if ! rpm -q "$pkg" > /dev/null 2>&1
        then
            packages_needed=yes
        fi
    done

    ## Install RPM Packages
    if [ "${packages_needed:-none}" == "yes" ]
    then
        printf "%s\n" "  The installer needs to install some RPMs before we can continue."
        confirm "  Do you want to continue? ${cyn:?}yes/no${end:?}"
        if [ "A${response}" == "Ano" ]
        then
            printf "%s\n" "  You can manually ensure all the below packages are installed and try again."
            printf '%s\n' "${packages_needed:-}"
            exit 0
        else
            # check if packages needs to be installed
            printf "%s\n\n" "  ${cyn:?}Installing required packages${end:?}"
            for pkg in $yum_packages
            do
                if ! rpm -q "$pkg" > /dev/null 2>&1
                then
                    if ! sudo yum install -y "$pkg" > /dev/null 2>&1
                    then
                        printf "%s\n" "  ${red:?}Failed to install "$pkg"${end:?}"
                        exit 1
                    fi
                fi
            done
	fi
    fi


    ## install pip3 packages
    if which /usr/bin/pip3 > /dev/null 2>&1
    then
        printf "%s\n" ""
        printf "%s\n" "  ${blu:?}Ensure required pip packages are present${end:?}"
        printf "%s\n" "  ${blu:?}***********************************************************${end:?}"
        for pkg in $pip_packages
        do
            if ! pip3 list --format=columns| grep "$pkg" > /dev/null 2>&1
            then
                printf "%s\n" "  ${cyn:?}Installing $pkg${end:?}"
                if ! /usr/bin/pip3 install "$pkg" --user > /dev/null 2>&1
		        then
	                printf "%s\n" "  ${red:?}Failed to $pkg ${end:?}"
		            exit 1
		        fi
            fi
        done
        printf "%s\n" "  ${yel:?}All pip packages are present${end:?}"
    fi
    install_packages_status="package_done"
    BASELINE_STATUS+=("$install_packages_status")
}

# @description
# Installs and sets up ansible.
function qubinode_setup_ansible ()
{
    ## define maintenace option
    local force_ansible
    local ansible_msg
    force_ansible="${qubinode_maintenance_opt:-none}"
    if ! which ansible-galaxy >/dev/null 2>&1
    then
        register_system
        install_packages
    fi

    if which ansible-galaxy >/dev/null 2>&1
    then
        printf "%s\n" ""
        printf "%s\n" "  ${blu:?}Ensure the ansible roles and collections are available${end:?}"
        printf "%s\n" "  ${blu:?}***********************************************************${end:?}"
        if which git >/dev/null 2>&1
	    then
            ansible_msg="Downloading required Ansible roles and collections"
            local result
            local ansible_galaxy_cmd
            result=$(ansible-galaxy role list | grep -v $project_dir | wc -l)
            # Ensure roles are downloaded
            if [ $result -eq 0 ]
            then
                printf "%s\n" "  ${ansible_msg}"
	            ansible-galaxy install -r "${ANSIBLE_REQUIREMENTS_FILE}" > /dev/null 2>&1
	            ansible-galaxy collection install -r "${ANSIBLE_REQUIREMENTS_FILE}" > /dev/null 2>&1
            else
	            if [ "${force_ansible}" == "ansible" ]
	            then
                    printf "%s\n" "  Force ${ansible_msg}"
	                ansible-galaxy collection install -r "${ANSIBLE_REQUIREMENTS_FILE}" > /dev/null 2>&1
                    ansible-galaxy install --force -r "${ANSIBLE_REQUIREMENTS_FILE}" > /dev/null 2>&1
	            fi
            fi
            printf "%s\n" "  ${yel:?}All ansible roles and collectiones are present${end:?}"
            printf "%s\n" ""
        else
            printf "%s\n" "  ${red:?}Error: git is required to continue. Please install git and try again.${end:?}"
	        exit 1
	    fi
    fi
    qubinode_setup_ansible_status="ansible_done"
    BASELINE_STATUS+=("$qubinode_setup_ansible_status")
}

##---------------------------------------------------------------------
##  Qubinode utility functions
##---------------------------------------------------------------------
# @description
# Reset project folder to default state by removing all var files
# from playbooks/vars. A backup of each var is stored under the backup
# directory.
function qubinode_project_cleanup () {
    test -d "${project_dir}/backups" || mkdir -p "${project_dir}"/backups/{vars,inventory}
    FILES=()
    timestamp=$(date -d "today" +"%Y%m%d%H%M")
    mapfile -t FILES < <(find "${project_dir}/inventory/" -not -path '*/\.*' -type f)
    mapfile -t FILES < <(find "${project_dir}/playbooks/vars/" -not -path '*/\.*' -type f)
    if [ ${#FILES[@]} -ne 0 ]
    then
        for f in "${FILES[@]}"
        do
            f_name=$(basename "$f")
            new_name="${f_name}.${timestamp}"
            if echo "$f"|grep -q inventory
            then 
                mv "$f" "${project_dir}/backups/inventory/${new_name}"
            fi

            if echo "$f"| grep -q vars
            then
                mv "$f" "${project_dir}/backups/vars/${new_name}"
            fi
        done
    fi
}

# @description
# Collect information about the kvm host hardware
function create_qubinode_profile_log () {
    if [[ ! -f "${project_dir}/qubinode_profile.log" ]]; then
        rm -rf "${project_dir}/qubinode_profile.log"
        collect_system_information
cat >"${project_dir}/qubinode_profile.log"<<EOF
Manufacturer: ${MANUFACTURER}
Product Name: ${PRODUCTNAME}

System Memory
*************
Avaliable Memory: ${AVAILABLE_MEMORY}
Avaliable Human Memory: ${AVAILABLE_HUMAN_MEMORY}

Storage Information
*******************
Avaliable Storage: ${AVAILABLE_STORAGE}
Avaliable Human Storage: ${AVAILABLE_HUMAN_STORAGE}

CPU INFO
***************
$(lscpu | egrep 'Model name|Socket|Thread|NUMA|CPU\(s\)')
EOF

    fi

    echo "SYSTEM REPORT"
    cat "${project_dir}/qubinode_profile.log"
}



##---------------------------------------------------------------------
##  MENU OPTIONS
##---------------------------------------------------------------------
# @description
# Displays help menu.
function display_help() {
    project_dir="${project_dir:-none}"
    if [ ! -d "$project_dir" ]
    then
        printf "%s\n" "   ${red:?}Error: could not locate ${project_dir}${end:?}" 
	    exit 1
    fi
    cat < "${project_dir}/docs/qubinode/qubinode-menu-options.adoc"
}

# @description
# The qubinode-installer -m options.
function qubinode_maintenance_options () {
    local options="${product_options[*]:?}"      
    if [ "A${options}" != "A" ]
    then
        _product_options_file=$(mktemp)
        for var_name in "${product_options[@]}"
        do
            echo "$var_name" >> "${_product_options_file}"
        done
        # shellcheck source=/dev/null
        # shellcheck disable=SC1091
        source "${_product_options_file}"
    else 
        local tags=""
    fi

    if [ "${qubinode_maintenance_opt}" == "setup" ]
    then
        printf "%s\n" "  ${blu:?}Running Qubinode Setup${end:?}"
        qubinode_baseline
        qubinode_vars
        qubinode_vault_file
    elif [ "${qubinode_maintenance_opt}" == "clean" ]
    then
        qubinode_project_cleanup
    elif [ "${qubinode_maintenance_opt}" == "rhsm" ]
    then
        ## Check system registration status
        check_rhsm_status
        ask_user_for_rhsm_credentials
        register_system
        qubinode_vars
        qubinode_vault_file
    elif [ "${qubinode_maintenance_opt}" == "ansible" ]
    then
        if [ "A${SYSTEM_REGISTERED}" != "Ayes" ]
        then
            echo "Please run ./qubinode-installer -m rhsm first"
            exit 1
        else
            qubinode_setup_ansible
            qubinode_vars
            qubinode_vault_file
        fi
    elif [ "${qubinode_maintenance_opt}" == "network" ]
    then
        setup_networking
        qubinode_vars
    elif [ "${qubinode_maintenance_opt}" == "kvmhost" ]
    then
        if [ "A${QUBINODE_BASELINE_COMPLETE:-no}" != 'Ayes' ]
        then
            cd "${project_dir}" || exit 1
            ./qubinode-installer -m setup
        else 
            ./qubinode-installer -m setup
        fi
	    local ansible_cmd
        local kvmhost_vars="${project_dir}/playbooks/vars/kvm_host.yml"
        local inventory="${project_dir}/inventory/hosts"

        if [ "A${tags}" != "A" ]
        then
            ansible_cmd="ansible-playbook ${project_dir}/playbooks/kvmhost.yml --tags $tags"
        else
            ansible_cmd="ansible-playbook ${project_dir}/playbooks/kvmhost.yml"
        fi

        if ! cd "${project_dir}"
        then 
            printf "%s\n" "  Error: ${red:?}Could not enter ${project_dir} ${end:?}"
            exit 1
        fi
        test -f "${kvmhost_vars}" || cp "${project_dir}/samples/kvm_host.yml" "${kvmhost_vars}"
        test -f "${inventory}" || cp "${project_dir}/samples/hosts" "${inventory}"


	    if [ -f "${inventory}" ] && [ -f "${kvmhost_vars}" ]
        then
            printf "%s\n" "  ${blu:?}Running Qubinode KVMHOST setup${end:?}"
            qubinode_vars
            qubinode_vault_file
	        echo "${ansible_cmd}"|sh
        else
            printf "%s\n" "  Error: ${red:?}Could locate ${kvmhost_vars} and ${inventory} ${end:?}"
        fi
#    elif [ "${qubinode_maintenance_opt}" == "hwp" ]
#    then
        # Collect hardware information
#        create_qubinode_profile_log
#    elif [ "${qubinode_maintenance_opt}" == "rebuild_qubinode" ]
#    then
#        rebuild_qubinode
#    elif [ "${qubinode_maintenance_opt}" == "undeploy" ]
#    then
#        #TODO: this should remove all VMs and clean up the project folder
#        qubinode_vm_manager undeploy
#    elif [ "${qubinode_maintenance_opt}" == "uninstall_openshift" ]
#    then
#      #TODO: this should remove all VMs and clean up the project folder
#        qubinode_uninstall_openshift
#    else
#        display_help
    fi
}

function qubinode_product_deployment () {
    local options="${product_options[*]:-none}"
    local qubinode_product="${qubinode_product_opt:?}"
    local product_maintenance="${product_maintenance:-none}"
    local teardown="${teardown:-no}"
    if [ "A${options}" != "A" ]
    then
        _product_options_file=$(mktemp)
        for var_name in "${product_options[@]}"
        do 
            if echo "$var_name" | grep -q '='
            then
                echo "$var_name" >> "${_product_options_file}"
            fi
        done
        # shellcheck source=/dev/null
        # shellcheck disable=SC1091
        source "${_product_options_file}"
    else 
        local tags=""
    fi

    case $qubinode_product in
        rhel)
            load_qubinode_vars
            echo "qubinode_product=$qubinode_product"
            echo "product_maintenance=$product_maintenance"
            echo "product_modifiers=${product_options[*]}"
            echo "teardown=$teardown"
            # shellcheck source=/dev/null
            # shellcheck disable=SC1091
            source "${project_dir}/lib/qubinode_rhel.sh"

            qubinode_rhel_vm_attributes
            qubinode_vars
            echo "vm_rhel_release=${vm_rhel_release:-none}"
            echo "rhel_vm_hostname=${rhel_vm_hostname:-none}"
            echo "rhel_vm_size=${rhel_vm_size:-none}"
            echo "rhel_vm_release=${rhel_vm_release:-none}"

            #if [ "A${teardown}" == "Atrue" ]
            #then
            #    qubinode_rhel_teardown
            #else
            #    if [ "A${qubinode_maintenance}" == "Atrue" ]
            #    then
            #        qubinode_rhel_maintenance
            #    else
            #        CHECK_PULL_SECRET=no
            #        #setup_download_options
            #        download_files
            #        qubinode_deploy_rhel
            #    fi
            #fi
            ;;
#          okd4)
#              openshift4_variables
#              if [ "A${teardown}" == "Atrue" ]
#              then
#                  openshift4_qubinode_teardown
#              elif [ "A${qubinode_maintenance}" == "Atrue" ]
#              then
#                  openshift4_server_maintenance
#              else
#                  ASK_SIZE=true
#                  qubinode_deploy_ocp4
#              fi
#              ;;
#          ocp4)
#              CHECK_PULL_SECRET=yes
#              openshift4_variables
#              if [ "A${teardown}" == "Atrue" ]
#              then
#                  openshift4_qubinode_teardown
#              elif [ "A${qubinode_maintenance}" == "Atrue" ]
#              then
#                  openshift4_server_maintenance
#              else
#                  ASK_SIZE=true
#                  CHECK_PULL_SECRET=no
#                  setup_download_options
#                  qubinode_deploy_ocp4
#              fi
#              ;;
#          satellite)
#              if [ "A${teardown}" == "Atrue" ]
#              then
#                  qubinode_teardown_satellite
#              else
#                  rhel_major=7
#                  CHECK_PULL_SECRET=no
#                  setup_download_options
#                  download_files
#                  qubinode_deploy_satellite
#              fi
#              ;;
#          tower)
#              if [ "A${teardown}" == "Atrue" ]
#              then
#                  qubinode_teardown_tower
#              else
#                  CHECK_PULL_SECRET=no
#                  setup_download_options
#                  download_files
#                  qubinode_deploy_tower
#              fi
#              ;;
#          idm)
#              if [ "A${teardown}" == "Atrue" ]
#              then
#                  echo "Running IdM VM teardown function"
#                  qubinode_teardown_idm
#              elif [ "A${qubinode_maintenance}" == "Atrue" ]
#              then
#                  qubinode_idm_maintenance
#              else
#                  CHECK_PULL_SECRET=no
#                  echo "Running IdM VM deploy function"
#                  setup_download_options
#                  download_files
#                  qubinode_deploy_idm
#              fi
#              ;;
          *)
              echo "Product ${PRODUCT_OPTION} is not supported."
              echo "Supported products are: ${AVAIL_PRODUCTS}"
              exit 1
              ;;
    esac

}
