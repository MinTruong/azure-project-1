# **azure-project-1: Azure Infrastructure Operations**
# Deploy policy 
* role-add-tags/policy.parameters.json : parameters for tags policy
* role-add-tags/policy.rule : rule of tags policy

Definition policy
```
az policy definition create --subscription <Subscription ID> --name tagging-policy --display-name tagging-policy --description "all indexed resources in your subscription have tags and deny deployment if they do not" --mode All --metadata "version"="1.0.1" "category"="Tags" --params "./role-add-tags/policy.parameters.json" --rules "./role-add-tags/policy.rule.json"
```
Assignment policy already created above
```
az policy assignment create --policy tagging-policy --name "tagging-policy"
```
# Create Azure Vm image
* env.bashrc : contains environment variable
* server.json : definition Vm image which use create Vm next step
>**Note**: In env.bashrc file you must definition environment variable follow **Service Principal Details** of Azure lab

Export environment variable
```
source env.bashrc
```
Build azure vm image by packer
```
packer build server.json
```

# Create Azure Vm with vm image already created above
* terraform/main.tf: declare resource will be create in main.tf .
* terraform/variables.tf: declare variable for resource.

The **terraform init** command is used to initialize a working directory containing Terraform configuration files. This is the first command that should be run after writing a new Terraform configuration or cloning an existing one from version control. It is safe to run this command multiple times
```
terraform init
```
Create resource on local
```
terraform plan
```
After terraform plan success, not error. Deploy the project on Azure without approve
```
terraform apply -auto-approve 
```


