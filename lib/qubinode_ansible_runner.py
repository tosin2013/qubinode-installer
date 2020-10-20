import ansible_runner
import os
from os import path
from ansible_vault import Vault
import argparse
import os.path
import json 
import sys
import pwd

#vault = Vault('xXxXxXxXx')
#data = vault.load(open('env/passwords').read())
username=str(os.environ.get('USER'))

print("Test this username: "+username)
def run_playbook(data_path, playbook_path, extra_vars, verbose, destroy):
  if verbose:
    level=3
  else:
    level=1
  print(extra_vars)

  if extra_vars is None:
    r = ansible_runner.run(private_data_dir='/home/cloud_user/qubinode-installer', playbook=playbook_path,verbosity=level, extravars={'vm_teardown': destroy})
    print("{}: {}".format(r.status, r.rc))
    # successful: 0
    #if verbose:
    #  for each_host_event in r.events:
    #    print(each_host_event['event'])
    print("Final status:")
    print(r.stats)
    print("error code: "+str(r.rc))
    if r.rc == 2:
      sys.exit(1)
  else:
    r = ansible_runner.run(private_data_dir='/home/cloud_user/qubinode-installer', playbook=playbook_path,verbosity=level, extravars=json.loads(extra_vars))
    print("{}: {}".format(r.status, r.rc))
    # successful: 0
    #if verbose:
    #  for each_host_event in r.events:
    #    print(each_host_event['event'])
    print("Final status:")
    print(r.stats)
    print("error code: "+str(r.rc))
    if r.rc == 2:
      sys.exit(1)

def clean_envvars():
  filePath = '/home/cloud_user/qubinode-installer/env/extravars'
  if os.path.exists(filePath):
      os.remove(filePath)
  else:
      print("Can not delete the file as it doesn't exists")

def main():
  # Creating the parser
  parse_item = argparse.ArgumentParser(description='Run ansible playbooks using ansible runner')
  parse_item.add_argument('PlaybookName',
                       metavar='playbook',
                       type=str,
                       help='Enter the playbook name. Example rhel.yml')
  parse_item.add_argument('-e',
                       '--extravars',
                       type=str,
                       help='set if you would like to pass an extravars command to the script.')
  parse_item.add_argument('-d',
                       '--destroy',
                       action='store_true',
                       help='set if you would like to destroy enviornment.')
  parse_item.add_argument('-v',
                       '--verbose',
                       action='store_true',
                       help='Set Verbosity of ansible playbook')

  # Execute the parse_args() method
  args = parse_item.parse_args()

  playbookname = args.PlaybookName

  print(args)
  print(playbookname)
  cwd = os.getcwd()
  print("PATH "+str(cwd))
  print ("File exists:"+str(path.exists(cwd+'/playbooks/'+playbookname)))
  run_playbook(cwd, playbookname, args.extravars, args.verbose, args.destroy)
  clean_envvars()

if __name__== "__main__":
   main()

