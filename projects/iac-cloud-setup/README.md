## Cloudformation IaC AWS Setup

### Technical Details

Region: Europe/Frankfurt (eu-central-1)
VPC IPv4 CIDR Block: 10.200.150.0/24
Number of AZ: 1
Number of Public Subnets: 1
Number of Private Subnets: 1
Nat Gateways: None
VPC ENdpoints: None 
DNS resolution: enabled
DHCP address assignment: enabled
VPC Ipv4 Public Subnet CIDR Block: 10.200.150.0/28
VPC Ipv4 Private Subnet CIDR Block: 10.200.150.128/28

SSH Key Region Europe/Frankfurt (eu-central-1)

Security Group:
  Inbound: 
    Ipv4 SSH Protocol TCP Port 22 Source MyIP
    Ipv4 RDP Protocol TCP Port 3389 Source MyIP
    Ipv4 All Traffic All Protocol All Ports in Subnet 10.200.150/24
  Outbound: 
    All Traffic All Protocol All  Port Destination 0.0.0.0/0

Virtual Machines:
  Region: eu-central-1
  RedHat:
    AMI: amazon/RHEL-10.0.0_HVM_GA-20250423-x86_64-0-Hourly2-GP3
    Instance Type: t2.medium
    Storage: 30GB gp3
  Ubuntu: 
    AMI: amazon/ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20250305 
    Instance Type: t2.medium
    Storage: 30GB gp3
  Microsoft Server 2025:
    AMI: amazon/Windows_Server-2025-English-Full-Base-2025.05.15
    Instance Type: t3.large
    Storage: 30GB gp3

3 extra Network Interfaces:
  1 For RedHat:
    Assign to VPC Ipv4 Private Subnet CIDR Block: 10.200.150.128/28
  1 For Ubuntu: 
    Assign to VPC Ipv4 Private Subnet CIDR Block: 10.200.150.128/28
  1 For Microsoft Server 2025:
    Assign to VPC Ipv4 Private Subnet CIDR Block: 10.200.150.128/28
    

### Deploy stack 

```bash

## setup cloudformation stack 
aws cloudformation create-stack \
  --stack-name multi-os-infrastructure \
  --template-body file://template.yaml \
  --parameters ParameterKey=KeyPairName,ParameterValue=<YOUR KEYPAIR NAME> \
               ParameterKey=MyIPAddress,ParameterValue=<YOUR_IP/32> \
  --region eu-central-1

## delete cloudformation stack 
aws cloudformation delete-stack --stack-name multi-os-infrastructure --region eu-central-1

## test cloudformation vms 
aws ec2 describe-instances \
  --region eu-central-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{Name: Tags[?Key==`Name`]|[0].Value, PublicIP: PublicIpAddress}' \
  --output table
[aczepiel@endeavour iac-cloud-setup]$ 
-------------------------------------
|         DescribeInstances         |
+----------------------+------------+
|         Name         | PublicIP   |
+----------------------+------------+
|  Ubuntu-Server       |  None      |
|  RedHat-Server       |  None      |
|  Windows-Server-2022 |  None      |
+----------------------+------------+
No public ips ! Cloud formation template should be optimized

## update stack
aws cloudformation update-stack \
  --stack-name multi-os-infrastructure \
  --template-body file://template.yaml \
  --region eu-central-1

# Now it works yaay 
[aczepiel@endeavour exp-net-fundamentals-2025-Q2]$ aws ec2 describe-instances   --region eu-central-1   --filters "Name=instance-state-name,Values=running"   --query 'Reservations[].Instances[].{Name: Tags[?Key==`Name`]|[0].Value, PublicIP: PublicIpAddress}'   --output table
------------------------------------------
|            DescribeInstances           |
+----------------------+-----------------+
|         Name         |    PublicIP     |
+----------------------+-----------------+
|  Ubuntu-Server       |  52.29.252.240  |
|  RedHat-Server       |  3.66.118.232   |
|  Windows-Server-2022 |  18.185.28.138  |
+----------------------+-----------------+

## delete stack command
aws cloudformation delete-stack --stack-name multi-os-infrastructure --region eu-central-1
```