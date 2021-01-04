Below are example VM calls

Example Python CLI commands to deploy generic rhel box
```
python3 lib/qubinode_ansible_runner.py rhel.yml
```

Example Python CLI commands to destroy generic rhel box
```
python3 lib/qubinode_ansible_runner.py rhel.yml -d 
```


JSON
```
{
   "rhel_server_vm": {
      "rhel_name": "rhelbox-1",
      "rhel_vcpu": 1,
      "rhel_memory": 800,
      "rhel_root_disk_size": "20G",
      "rhel_teardown": false,
      "rhel_recreate": false,
      "rhel_group": "rhel",
      "rhel_extra_storage": [
         {
            "size": "",
            "enable": false
         }
      ],
      "rhel_enable": true
   },
   "cloud_init_vm_image": "rhel-server-7.8-x86_64-kvm.qcow2",
   "qcow_rhel_release": 7,
   "rhel_release": 7,
   "rhel_8_hash": null,
   "rhel_7_hash": null,
   "update_etc_resolv": "no",
   "expand_os_disk": "no",
   "vm_root_disk_size": "{{ rhel_server_vm.rhel_root_disk_size }}"
}

```

YAML
```
rhel_server_vm:
    rhel_name: "rhelbox-1"
    rhel_vcpu: 1
    rhel_memory: 800
    rhel_root_disk_size: 20G
    rhel_teardown: false
    rhel_recreate: false
    rhel_group: rhel
    rhel_extra_storage:
      - size: ""
        enable: false
    rhel_enable: true

cloud_init_vm_image: "rhel-server-7.8-x86_64-kvm.qcow2"
qcow_rhel_release: 7
rhel_release: 7
rhel_8_hash:
rhel_7_hash:
update_etc_resolv: no
expand_os_disk: no
vm_root_disk_size: "{{ rhel_server_vm.rhel_root_disk_size }}"
```