## Cloud Environment Setup

### In AWS I created the following setup

* VPC in Region Frankfurt
    * VPC Subnet CIDR 10.200.150.0/24
* VPC Public Subnet and Private Subnet
    * Public Subnet 10.200.150.0/28 
    * Private Subnet 10.200.150.128/28
* SSH pem key for region franfurt 
* Security Group allow-login with following setup
    * Allow SSH from MyIP
    * Allow RDP from MyIP
    * Allow All Traffic from Subnet 10.200.150.0/24
* 3 Network Interfaces for Private Subnet 10.200.150.128/28#
* 3 Virtual Machines (all vms got a second nic from private subnet)
    * Windows Server Test
    * Red Hat Server Test 
    * Ubuntu Server Test