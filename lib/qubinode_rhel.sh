#!/bin/bash

function qubinode_deploy_rhel () {
    setup_variables
    RHEL_VM_PLAY="${project_dir}/playbooks/rhel.yml"
    rhel_vars_file="${project_dir}/playbooks/vars/rhel.yml"

    product_in_use=rhel
    prefix=$(awk '/instance_prefix/ {print $2;exit}' "${vars_file}")
    suffix=rhel

    # Generate a random id that's not already is use for the cattle vms
    while true
    do
        instance_id=$((1 + RANDOM % 4096))
        if ! sudo virsh list --all | grep $instance_id
        then
            break
        fi
    done

    # Check for user provided variables
    for var in "${product_options[@]}"
    do
        local $var
    done

    if [ "A${release}" != "A" ]
    then
        rhel_release="$release"
    else
        rhel_release=7
    fi

    if [ "A${name}" != "A" ]
    then
        rhel_server_hostname="${prefix}-${name}"
    else
        rhel_server_hostname="${prefix}-${suffix}${release}-${instance_id}"
    fi

    # Get instance size
    if [ "A${size}" != "A" ]
    then
        if [ "A${size}" == "Asmall" ]
        then
            echo "Setting VM size to small"
            vcpu=1
            memory=800
            disk=20G
        elif [ "A${size}" == "Amedium" ]
        then
            echo "Setting VM size to medium"
            vcpu=2
            memory=2048
            disk=60G
        elif [ "A${size}" == "Alarge" ]
        then
            echo "Setting VM size to large"
            vcpu=4
            memory=8192
            disk=200G
        else
            echo "using default size"
       fi
    else
        echo "Setting VM size to small"
        vcpu=1
        memory=800
        disk=20G
    fi

    # Default RHEL release to deploy
    if [ "A${release}" == "A7" ]
    then
        qcow_image="rhel-server-7.7-update-2-x86_64-kvm.qcow2"
        echo $release is $release and qcow is $qcow_image
    elif [ "A${release}" == "A8" ]
    then
        qcow_image="rhel-8.2-x86_64-kvm.qcow2"
        echo $release is $release and qcow is $qcow_image
    else
        qcow_image="rhel-server-7.7-update-2-x86_64-kvm.qcow2"
    fi

    rhel_server_fqdn="${rhel_server_hostname}.${domain}"

    # Ensure rhel vars file is active
    if [ ! -f "${rhel_vars_file}" ]
    then
        cp "${project_dir}/samples/rhel.yml" "${rhel_vars_file}"
    fi

    sed -i "s/rhel_name:.*/rhel_name: "$rhel_server_hostname"/g" "${rhel_vars_file}"
    sed -i "s/rhel_vcpu:.*/rhel_vcpu: "$vcpu"/g" "${rhel_vars_file}"
    sed -i "s/rhel_memory:.*/rhel_memory: "$memory"/g" "${rhel_vars_file}"
    sed -i "s/rhel_root_disk_size:.*/rhel_root_disk_size: "$disk"/g" "${rhel_vars_file}"
    sed -i "s/cloud_init_vm_image:.*/cloud_init_vm_image: "$qcow_image"/g" "${rhel_vars_file}"
    echo $rhel_server_hostname
    echo $rhel_server_fqdn

    echo RHEL_QCOW="${project_dir}/${qcow_image}"
    # Ensure the RHEL qcow image is at /var/lib/libvirt/images
    RHEL_QCOW_SOURCE="/var/lib/libvirt/images/${qcow_image_file}"
    if [ ! -f "{RHEL_QCOW_SOURCE}" ]
    then
        if [ -f "${project_dir}/${qcow_image}" ]
        then
             sudo cp "${project_dir}/${qcow_image}" "${RHEL_QCOW_SOURCE}" 
        else
            echo "Please download ${qcow_image} to ${RHEL_QCOW_SOURCE}"
            exit 1
        fi
    fi

    qcow_image_file="/var/lib/libvirt/images/${rhel_server_hostname}_vda.qcow2"
    if ! sudo virsh list --all |grep -q "${rhel_server_hostname}"
    then
        PLAYBOOK_STATUS=0
        sudo test -f $qcow_image_file && sudo rm -f $qcow_image_file 
        echo "Deploying $rhel_server_hostname"
        ansible-playbook "${RHEL_VM_PLAY}"
        PLAYBOOK_STATUS=$?
    fi

    # check if VM was deployed, if not delete the qcow image created for the vm
    if ! sudo virsh list --all |grep -q "${rhel_server_hostname}"
    then
        sudo test -f $qcow_image_file && sudo rm -f $qcow_image_file
    fi

   # return the status of the playbook run
   return $PLAYBOOK_STATUS
}


#function qubinode_teardown_rhel () {
#     IDM_PLAY_CLEANUP="${project_dir}/playbooks/rhel_server_cleanup.yml"
#     if sudo virsh list --all |grep -q "${rhel_server_hostname}"
#     then
#         echo "Remove IdM VM"
#         ansible-playbook "${RHEL_VM_PLAY}" --extra-vars "vm_teardown=true" || exit $?
#     fi
#     echo "Ensure IdM server deployment is cleaned up"
#     ansible-playbook "${IDM_PLAY_CLEANUP}" || exit $?
#
#     printf "\n\n*************************\n"
#     printf "* IdM server VM deleted *\n"
#     printf "*************************\n\n"
#}
#
#function qubinode_deploy_rhel_vm () {
#    if grep deploy_rhel_server "${rhel_vars_file}" | grep -q yes
#    then
#        qubinode_vm_deployment_precheck
#        isIdMrunning
#
#        IDM_PLAY_CLEANUP="${project_dir}/playbooks/rhel_server_cleanup.yml"
#        SET_IDM_STATIC_IP=$(awk '/rhel_check_static_ip/ {print $2; exit}' "${rhel_vars_file}"| tr -d '"')
#
#        if [ "A${rhel_running}" == "Afalse" ]
#        then
#            echo "running playbook ${RHEL_VM_PLAY}"
#            if [ "A${SET_IDM_STATIC_IP}" == "Ayes" ]
#            then
#                echo "Deploy with custom IP"
#                rhel_server_ip=$(awk '/rhel_server_ip:/ {print $2}' "${rhel_vars_file}")
#                ansible-playbook "${RHEL_VM_PLAY}" --extra-vars "vm_ipaddress=${rhel_server_ip}"|| exit $?
#             else
#                 echo "Deploy without custom IP"
#                 ansible-playbook "${RHEL_VM_PLAY}" || exit $?
#             fi
#         fi
#     fi
#}
#