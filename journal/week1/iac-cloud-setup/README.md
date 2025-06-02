## IAC AWS Cloud Setup

[Back to Week Overview](../README.md)<br/>
[Back to Main](../../README.md)

I decided to setup my aws cloud environment with AWS Cloudformation.
This has also the advantange that later i can setup CI/CD and automate the setup with a pipeline. Also i can deploy and destroy it whenever i want.

Its also less error prone cause it's a fixed configuration.

The environment structure should look like this [structure](../cloud-env-setup/README.md). The IaC code can be found in [cloud env setup](../../../projects/iac-cloud-setup/README.md) section.

### Journal [Link]
* First i needed to install the aws cli and setup aws credentials for making aws cloudfoirmation to work
* i watched the video from andrew about cloudformation and also install vscode extension aws toolkit with aws with infrastructure composer as feature
* the [ai spec](./../../../projects/iac-cloud-setup/README.md) is the final version of cloudformation
  * issues:
    * first issue was that vscode ran into errors it could noit handle cloudformation !Ref and 
    * i had an issue that all three vms in the vpc with tghe public nic, it was noit assigned so the vms were without public ip connection
* ip updated the temnplate.yaml file and the missing public ips were assigned
* i tested it by connection via ssh and freerdp to the virtual machines in aws and it worked
* problem solved 



