# Network test
A Terraform setup to test network on the Uppmax region.

```
export TF_VAR_cluster_prefix="nettest"
export TF_VAR_ssh_key="~/.ssh/id_rsa"
export TF_VAR_ssh_key_pub="~/.ssh/id_rsa.pub"
export TF_VAR_node_count="30"
export TF_VAR_command="echo alive"
terraform init
terraform apply
```
