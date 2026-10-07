# DevOps assessment

Terraform for the Arrise DevOps assessment: a five-instance EC2 fleet, remote state with locking, cross-account IAM, a least-privilege CI policy, and the fix for the broken `roleC` trust.

Written answers are in [NOTES.md](NOTES.md).

## Layout

```text
modules/ec2-fleet/          Task 1 module. One variable, for_each, no copied resource blocks per instance.
environments/ec2/           Root module that calls the fleet and configures the S3 backend.
bootstrap/remote-state/     S3 bucket and DynamoDB lock table. Local state, on purpose.
environments/iam/           Tasks 3, 4, and 5. Account A and Account B.
policies/ci-pipeline.json   Task 4 policy, attached only to the ci user.
```

## Task 1 fleet

All five instances are the default of `environments/ec2/variables.tf` `instances`. The module splits that map into two resources only because `prevent_destroy` has to be a literal. See NOTES.md.

| Name | Instance type | Root volume | Size | IOPS | Key pair | Protected |
| --- | --- | --- | --- | --- | --- | --- |
| web-01 | t3.micro | standard | 30 GiB |  | arrise-web-01 |  |
| web-02 | t3.small | gp2 | 40 GiB |  | arrise-web-02 |  |
| api-01 | t3.medium | gp3 | 50 GiB |  | arrise-api-01 |  |
| worker-01 | t3.large | io1 | 80 GiB | 1000 | arrise-worker-01 |  |
| db-01 | m5.large | io2 | 100 GiB | 3000 | arrise-db-01 | yes |

`standard`, `gp2`, `gp3`, `io1`, and `io2` are the five EBS types AWS accepts as a root volume. `st1` and `sc1` cannot boot an instance.

Every instance is tagged `Name`, `Environment`, and `Owner`. Root volumes are encrypted. IMDSv2 is required. Port 22 stays closed unless `ssh_cidr` is set, and `0.0.0.0/0` is rejected.

Outputs:

- `instance_ids`: instance name to instance ID
- `instance_private_ips`: instance name to private IP

## Validate

```bash
make validate
```

This checks formatting, parses the CI policy, and runs `terraform validate` in all three stacks. No AWS credentials are required. `terraform init` uses `-backend=false` so it does not contact the state bucket.

## Apply

Use Terraform 1.4 or newer and AWS credentials for the target account. The sample account IDs in the IAM stack are the ones from the brief (`000000000000` and `111111111111`). Replace them, the bucket names, and the external ID before applying to real accounts.

1. Create the state backend. This stack keeps local state because the bucket does not exist yet.

   ```bash
   cd bootstrap/remote-state
   terraform init
   terraform apply
   ```

   If the bucket name is already taken, change `state_bucket_name` and `lock_table_name`, then put the same names in both `environments/*/backend.tf` files.

2. Apply the fleet and the IAM stacks. Each has its own state key and both use the same lock table.

   ```bash
   cd environments/ec2
   terraform init
   terraform apply

   cd ../iam
   terraform init
   terraform apply
   ```

The EC2 account needs a default VPC, or set `subnet_id`. `terraform destroy` on the fleet stops on `db-01` until `prevent_destroy` is removed and `disable_api_termination` is set back to false. Destroy on the bootstrap stack stops on the state bucket and the lock table for the same reason.

Generated SSH keys, access keys, and console passwords are marked sensitive. They land in state, which is why the state bucket is encrypted, versioned, and private. Read them with `terraform output -json <name>` and do not commit `terraform.tfstate` or a real `terraform.tfvars`.

## How the IAM roles are used

`group1` is `engine` and `ci`. They get access keys and no console password. `ci` also gets `policies/ci-pipeline.json`, and that policy is the user's permissions boundary.

`group2` is `vikash` and `meera`. They get a console password and an access key. Their group can assume `roleA` and `roleB` only. MFA is required. Register an MFA device, then:

```bash
aws sts get-session-token \
  --serial-number arn:aws:iam::000000000000:mfa/vikash \
  --token-code 123456

aws sts assume-role \
  --role-arn arn:aws:iam::000000000000:role/roleB \
  --role-session-name vikash-to-b

aws sts assume-role \
  --role-arn arn:aws:iam::111111111111:role/roleC \
  --role-session-name vikash-rolec \
  --external-id arrise-assessment-external-id
```

The last call has to be made with `roleB` credentials. `roleC` trusts that role ARN and rejects every other principal in Account A.
