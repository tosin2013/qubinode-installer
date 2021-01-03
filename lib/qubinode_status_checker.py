import requests
import argparse
import sys
def check_idm_status(fqdn,verify_ssl):
  request = requests.get('https://'+str(fqdn)+'/ipa/config/ca.crt', verify=verify_ssl )
  if request.status_code == 200:
    print('IdM server is installed')
    print('****************************************************')
    print('Webconsole: https://'+str(fqdn)+'/ipa/ui/')
    print('IP Address: ')
    print('Username: ')
    print('Password:')
  else:
    print('IDM Server was not properly deployed please verify deployment')
    sys.exit(1)


def select_product(argument,fqdn,verify_ssl):
    if argument == 'idm':
      check_idm_status(fqdn,verify_ssl)
    else:
      print("Product not Found.")
      sys.exit(1)

def main():
  # Creating the parser
  parse_item = argparse.ArgumentParser(description='Run ansible playbooks using ansible runner')
  parse_item.add_argument('product',
                       metavar='product',
                       type=str,
                       help='Enter the product name to check status. Example for DNS: qbn-dns01')
  parse_item.add_argument('fqdn',
                       metavar='fqdn',
                       type=str,
                       help='Enter the fqdn of project name to check status. Example for DNS: qbn-dns01.example.com')
  parse_item.add_argument('-s',
                       '--verify_ssl',
                       action='store_true',
                       help='Verify SSL when checking endpoint.')
  # Execute the parse_args() method
  args = parse_item.parse_args()

  productname = args.product
  select_product(productname, args.fqdn, args.verify_ssl)

if __name__== "__main__":
   main()