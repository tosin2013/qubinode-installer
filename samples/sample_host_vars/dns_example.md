Example of DNS Sever for developers

Example Python CLI commands to deploy DNS server
```
python3 lib/qubinode_ansible_runner.py idm_vm_deployment.yml
python3 lib/qubinode_ansible_runner.py idm_server.yml
```

Example Python CLI commands to deploy DNS destory server
```
python3 lib/qubinode_ansible_runner.py idm_server.yml -d
python3 lib/qubinode_ansible_runner.py idm_vm_deployment.yml -d
```


qubinode_status_checker.py

Example REST calls to deploy DNS Server
```
```

JSON
```
{
   "ask_use_existing_idm": "yes",
   "vm_teardown": false,
   "deploy_idm_server": "yes",
   "dns_server_vm": {
      "dns_enable": true,
      "dns_expand_os_disk": "no",
      "dns_extra_storage": [],
      "dns_gateway": "{{ vm_net_gateway | default('', true) }}",
      "dns_group": "dns",
      "dns_ip": "{{ idm_server_ip | default('', true) }}",
      "dns_mask": "{{ vm_net_netmask | default('', true) }}",
      "dns_mask_prefix": "{{ kvm_host_mask_prefix | default(kvm_host_mask_prefix) }}",
      "dns_memory": 2048,
      "dns_name": "{{ idm_hostname }}",
      "dns_recreate": false,
      "dns_root_disk_size": "10G",  - 1.168.192.in-addr.arpa
  - 50.168.192.in-addr.arpa
      "dns_teardown": "{{ vm_teardown }}",
      "dns_vcpu": 2
   },
   "expand_os_disk": "no",
   "idm_admin_password": "CHANGEME",
   "idm_admin_user": "admin",
   "idm_check_static_ip": "",
   "idm_forward_ip": "{{ dns_forwarder }}"  - 1.168.192.in-addr.arpa
  - 50.168.192.in-addr.arpa
   "idm_server_ip": "192.168.1.2",
   "idm_ssh_pwd": "CHANGEME",
   "idm_ssh_user": "{{ admin_user }}",
   "idm_zone_overlap": false,
   "ipa_host": "{{ idm_hostname }}.{{ domain }}",
   "qcow_rhel_release": 7,
   "rhel_release": 7
}
```

YAML
```
```