## IAC AWS Cloud Setup

[Back to Week Overview](../README.md)<br/>
[Back to Main](../../README.md)

I decided to setup my aws cloud environment with AWS Cloudformation.
This has also the advantange that later i can setup CI/CD and automate the setup with a pipeline. Also i can deploy and destroy it whenever i want.

Its also less error prone cause it's a fixed configuration.

The environment structure should look like this [structure](../cloud-env-setup/README.md). The IaC code can be found in [cloud env setup](../../../projects/iac-cloud-setup/README.md) section.

### Journal [Link]

* After defined the [ai spec](./../../../projects/iac-cloud-setup/README.md) for first version of cloudformation i had an issue that all three vms in the vpc had no public ip
* ip updated the temnplate.yaml file and the missing public ips were assigned
* i tested it by connection via ssh and freerdp to the virtual machines in aws and it worked
* problem solved 



