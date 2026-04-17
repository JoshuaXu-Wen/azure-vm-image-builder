# This script is used to trigger AAP workflow for image build and vm configuration, and check the job status until completion.
import sys, requests, ast, time, argparse
from urllib.parse import urljoin
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def get_paginated_results(url: str, auth_token: str) -> list:
  '''Helper function to retrieve paginated results from AAP API
  Args:
    url: API endpoint URL to retrieve data from
    auth_token: AAP token for authentication
  Returns:   
    List of results retrieved from the API
  Raises:
    ValueError: If API request fails or returns an error status code
  '''
  results = []
  headers = {
    'Content-Type': 'application/json',
    'Authorization': f'Bearer {auth_token}'
  }
  while url:
    response = requests.get(url=url, headers=headers, verify=False)
    if response.status_code == 200:
      data = response.json()
      results.extend(data.get('results', []))
      url = data.get('next')
    else:
      raise ValueError(f"Failed to retrieve data from {url}. Status code: {response.status_code}, Response: {response.text}")
  return results

def get_id_by_name(results: list, name: str) -> str:
  '''Helper function to get item ID from a list of results based on the item name
  Args:
    results: List of items retrieved from the API
    name: Name of the item to find the ID for
  Returns:
    ID of the item with the specified name
  Raises:
    ValueError: If item with the specified name is not found in the results
  '''
  for item in results:
    if item.get("name") == name:
      return item.get("id")
  else:
    raise ValueError(f"Item with name '{name}' not found in results")

def format_inventory_name(operation: str,tags: dict) -> str:
  '''
  Helper function to format inventory name based on the operation type and vm tags
  Args:
    operation: The type of operation, e.g. "image-build" or "vm-config"
    tags: The vm tags in dictionary format, e.g. {"env":"prod","app":"web","location":"eastus","os":"rhel"}
  Returns:
    Formatted inventory name, e.g. "azurevm_rhel_eastus_prod_image_build_inventory"
  '''
  location_var = tags.get("location").lower()
  env_var = tags.get("environment").lower()
  os_var = "rhel" if "rhel" in tags.get("os", "").lower() else "win"
  if operation == "image-build":
    inventory_name = f"azurevm_{os_var}_{location_var}_{env_var}_image_build_inventory"
  else:
    inventory_name = f"azurevm_{os_var}_{location_var}_{env_var}_config_inventory"
  return inventory_name

def get_inventory_id_from_name(aap_server: str, aap_token: str, inventory_name: str) -> str:
  '''
  Helper function to get inventory ID from AAP based on the inventory name
  Args:
    aap_server: AAP server URL
    aap_token: AAP token for authentication
    inventory_name: Name of the inventory to find the ID for
  Returns:
    ID of the inventory with the specified name
  Raises:
    ValueError: If inventory with the specified name is not found or API request fails
  '''
  url = urljoin(aap_server, f'/api/v2/inventories/?name={inventory_name}')
  headers = {
    'Content-Type': 'application/json',
    'Authorization': f'Bearer {aap_token}'
  }
  try:
    all_inventories = get_paginated_results(url, aap_token)  # to ensure the inventory exists and is accessible
  except ValueError as e:
    print(f"Error occurred while fetching inventories: {e}")
    sys.exit(1)
  
  return get_id_by_name(all_inventories, inventory_name)
  

def trigger_aap_workflow(aap_server: str, aap_token: str, workflow_template_id: str, extra_vars: dict, limit: str, inventory: str) -> dict:
  '''
  Function to trigger AAP workflow using the API
  Args:
    aap_server: AAP server URL
    aap_token: AAP token for authentication
    workflow_template_id: ID of the AAP workflow template to trigger
    extra_vars: Extra variables to pass to the workflow, in dictionary format
    limit: Limit parameter to specify which hosts in the inventory to run the workflow on
    inventory: Inventory ID to specify which inventory to use for the workflow
  Returns:
    Response from the API after triggering the workflow, in dictionary format
  Exceptions:
    ValueError: If API request fails or returns an error status code
  '''
  url = urljoin(aap_server, f'/api/v2/workflow_templates/{workflow_template_id}/launch/')
  headers = {
    'Content-Type': 'application/json',
    'Authorization': f'Bearer {aap_token}'
  }
  payload = {
    "extra_vars": extra_vars,
    "limit": limit,
    "inventory": inventory
  }

  ATTEMPT = 0
  MAX_RETRIES = 3
  while ATTEMPT < MAX_RETRIES:
    try:
      response = requests.post(
        url=url,
        headers=headers,
        json=payload, 
        verify=False)
      
      if response.status_code == 201:
        print(f"Successfully triggered AAP workflow. Response: {response.json()}")
        return response.json()
      else:
        print(f"Failed to trigger AAP workflow. Status code: {response.status_code}, Response: {response.text}")
    except Exception as e:
      print(f"Error triggering AAP workflow: {e}")

    ATTEMPT += 1
    print(f"Retrying... Attempt {ATTEMPT}/{MAX_RETRIES}")
    time.sleep(5)  # wait before retrying
  else:
    print("Exceeded maximum retry attempts. Exiting.")
    sys.exit(1)

# get job status, used to check if the job runs successfully after being triggered
def get_aap_job_status(aap_server: str, aap_token: str, job_id: str):
  '''
  Function to get AAP job status using the API, and wait until the job is completed
  Args:
    aap_server: AAP server URL
    aap_token: AAP token for authentication
    job_id: ID of the AAP job to check status for
  Returns:
    None, but will print the job status and exit the program if the job fails or does not complete successfully
  Exceptions:
    ValueError: If API request fails or returns an error status code
  '''
  ATTEMPT = 0
  MAX_RETRIES = 40
  url = urljoin(aap_server, f'/api/v2/jobs/{job_id}/')
  headers = {
    'Content-Type': 'application/json',
    'Authorization': f'Bearer {aap_token}'
  }
  while ATTEMPT < MAX_RETRIES:
    try:
      response = requests.get(
        url=url,
        headers=headers,
        verify=False)
      
      if response.status_code == 200:
        job_data = response.json()
        job_status = job_data.get('status')
        print(f"Job status: {job_status}")
        if job_status in ['successful', 'failed', 'error', 'canceled']:
          break  # job is completed, exit the loop
      else:
        print(f"Failed to get AAP job status. Status code: {response.status_code}, Response: {response.text}")
    except Exception as e:
      print(f"Error getting AAP job status: {e}")

    ATTEMPT += 1
    print(f"Retrying... Attempt {ATTEMPT}/{MAX_RETRIES}")
    time.sleep(60)  # wait before retrying
  else:
    print("Exceeded maximum retry attempts while checking job status. Exiting.")
    sys.exit(1)

  if job_status != 'successful':
    print(f"AAP job did not complete successfully. Final status: {job_status}. Exiting.")
    sys.exit(1)


def main():
  argparser = argparse.ArgumentParser(description='Trigger AAP workflow for image build')
  argparser.add_argument('--aap-server', required=True, help='AAP server URL')
  argparser.add_argument('--workflow-template-id', required=True, help='AAP workflow template ID to trigger')
  argparser.add_argument('--aap-token', required=True, help='AAP token for authentication')
  argparser.add_argument('--server-name', required=True, help='list of servers to run the workflow on, in json string format, e.g. ["server1","server2"]')
  argparser.add_argument('--server-ip', required=True, help='list of server IPs, in json string format, e.g. ["10.0.0.1","10.0.0.2"]')
  argparser.add_argument('--vm-tags', required=True, help='vm tags in json string format, e.g. {"env":"prod","app":"web"}')
  argparser.add_argument('--operation', required=True, help='operation to perform, e.g. "image-build" or "vm-config"')

  try:
    args = argparser.parse_args()
    aap_server = args.aap_server
    workflow_template_id = args.workflow_template_id
    aap_token = args.aap_token
    server_names = ast.literal_eval(args.server_name)
    server_ips = ast.literal_eval(args.server_ip)
    vm_tags = ast.literal_eval(args.vm_tags)
    operation = args.operation
  except Exception as e:
    print(f"Error parsing arguments: {e}")
    sys.exit(1)

  # get the inventory id based on the operation type and vm tags, 
  # e.g. azurevm_rhel_eastus_prod_image_build_inventory, azurevm_win_westus_dev_config_inventory, etc. 
  # The inventory should be pre-created in AAP with the correct host variables to run the workflow successfully
  inventory_name = format_inventory_name(operation, vm_tags)
  try:
    inventory_id = get_inventory_id_from_name(aap_server, aap_token, inventory_name)
  except ValueError as e:
    print(f"Error occurred while fetching inventory: {e}")
    sys.exit(1)

  # construct the server list to pass as extra vars to the AAP workflow, e.g. [{"server_name": "server1", "server_ip": "10.0.0.1"}]
  SERVERS = [
    {
      "server_name": name.strip(),
      "server_ip": ip.strip()
    }
    for name, ip in zip(server_names, server_ips)] 
  
  # construct extra vars to pass to the AAP workflow, including server list, operation name, os type, and vm tags
  extra_vars = {
    "server_list": SERVERS,
    "operation_name": operation,
    "os_type": "Linux" if "rhel" in vm_tags["os"].lower() else "Windows",
    "vm_tags": vm_tags
  }
  # construct the limit parameter to specify which hosts in the inventory to run the workflow on, 
  # in this case we use server names, but it can be modified to use other host variables defined in the inventory
  limit = server_names
  inventory = inventory_id

  # trigger the AAP workflow and get the job ID from the response, then check the job status until completion
  response = trigger_aap_workflow(aap_server, aap_token, workflow_template_id, extra_vars, limit, inventory)
  job_id = response.get('job')
  if job_id:
    print(f"Triggered AAP workflow with Job ID: {job_id}.")
    if operation in ["image-build", "vm-config"]:
      time.sleep(900)  # wait for 15 minutes before checking job status, as image build and vm config usually take a long time
    else:
      time.sleep(120)  # wait for 2 minutes before checking job status for other
  else:
    print("Failed to retrieve Job ID from AAP workflow response. Exiting.")
    sys.exit(1)

  # check AAP job status until completion
  get_aap_job_status(aap_server, aap_token, job_id)
