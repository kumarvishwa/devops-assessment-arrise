# Notes

## Task 1 — which instance is protected, and why

`db-01` is the protected instance.

It is the database node: `m5.large`, an encrypted `io2` root volume of 100 GiB, and `delete_on_termination = false`. Destroying it deletes the only stateful machine in the fleet. The other four are stateless (`web-01`, `web-02`, `api-01`, `worker-01`) and can be replaced.

Two controls are in place, because they stop different people:

- `lifecycle { prevent_destroy = true }` stops Terraform from destroying `db-01`, including a `terraform destroy` of the whole stack.
- `disable_api_termination = true` stops the EC2 API, the console, and the CLI from terminating that instance.

`ignore_changes = [ami]` is on `db-01` as well. The AMI is a `most_recent` lookup. A newer Amazon Linux AMI would otherwise plan a replacement, `prevent_destroy` would reject that plan, and every later apply of the fleet would fail. The stateless instances can still be replaced.

Terraform requires `prevent_destroy` to be a literal `true` or `false`. It cannot be `each.value.prevent_destroy` inside one `aws_instance`. The module still takes one variable, `instances`, and splits it:

- entries with `prevent_destroy = false` go to `aws_instance.standard`
- the one entry with `prevent_destroy = true` goes to `aws_instance.protected`

A validation rejects any map that does not contain exactly one protected instance. Removing `db-01` from the map, or destroying the stack, fails until that lifecycle block is edited on purpose.

`worker-01` uses `io1` and `db-01` uses `io2`, so the fleet meets the provisioned-IOPS requirement. I gave every instance a different root volume type because the brief asks for that. The only five types AWS allows on a root volume are `standard`, `gp2`, `gp3`, `io1`, and `io2`. `st1` and `sc1` cannot boot an instance. `standard` is previous-generation magnetic; it is on `web-01` only to make the five types distinct. In a real fleet I would put `io2` on the database and `gp3` on the stateless nodes.

The module creates a different ED25519 key pair for each instance because the brief asks for a different key pair. For a real fleet I would drop SSH keys and use SSM Session Manager. Port 22 is closed unless an operator passes a specific `ssh_cidr`, and `0.0.0.0/0` is rejected.

## Task 2 — local state races, and what the backend changes

With local state, `terraform.tfstate` is a file on one laptop. The `.terraform.tfstate.lock.info` file only locks that directory. It does nothing for a second person on another machine.

If two people run apply at the same time:

1. Both read the same state.
2. Each plan is built from that copy.
3. Both write the whole state file at the end.
4. The last write replaces the other one.

Whatever the first apply created is then missing from state. Those resources still exist in AWS, so they are orphaned. The next apply can create duplicates, or a destroy in the second plan can remove something the first apply still depends on. If the writes interleave, the file can also end up as invalid JSON and nobody can plan until it is restored by hand.

The EC2 and IAM root modules use an S3 backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "vk-arrise-devops-tfstate"
    key            = "ec2/terraform.tfstate" # iam/terraform.tfstate for the other stack
    region         = "us-east-1"
    dynamodb_table = "vk-arrise-devops-tflock"
    encrypt        = true
  }
}
```

The backend block is on the root module, not inside `modules/ec2-fleet`. Terraform does not allow a backend inside a child module.

`bootstrap/remote-state` creates the bucket and the lock table. That stack stays on local state because the bucket cannot store its own state before it exists. Its own `prevent_destroy` stops an accidental destroy of the bucket or the lock table.

Before an apply, Terraform writes an item to DynamoDB whose partition key is `LockID` (the state object path) and whose condition is `attribute_not_exists(LockID)`. The second apply's conditional write fails. Terraform waits until `-lock-timeout`, then errors. It does not read or write state while the other lock is held. The lock item records who holds it. The lock is released when the apply finishes, including after a failure. `-lock=false` skips this and should not be used.

The bucket also has versioning, AES256 encryption, Block Public Access, and a bucket policy that denies non-TLS requests. Versioning is the recovery path if a bad apply writes a bad state object: copy the previous version back. Encryption and the TLS deny keep the state, which contains access keys and generated SSH private keys, off the public internet and off plaintext HTTP.

One DynamoDB table locks both state keys. The lock ID includes the object key, so an EC2 apply and an IAM apply do not block each other. Two EC2 applies do.

## Task 3 — access keys, and the roleC trust

I would not give `engine` or `ci` IAM users with long-lived access keys in production.

`ci` is a pipeline. I would federate the CI system with OIDC (GitHub Actions or GitLab) and let it assume a dedicated role. The job gets temporary credentials from STS. There is no access key to leak into a log, a repo, or Terraform state. `engine` is a person. I would put that person in IAM Identity Center with MFA and a permission set, not an IAM user.

This configuration still creates those users, access keys, and no console password for `group1`, because the brief asks for that shape and then asks what I would do instead. `ci` is the only user with the pipeline policy, and that same policy is `ci`'s permissions boundary, so attaching `AdministratorAccess` later still cannot grant anything outside the pipeline policy. `engine` is in the programmatic group and has no service permissions until a separate policy exists for that person's actual job.

`group2` (`vikash` and `meera`) is the console-and-CLI pair: a password that must be changed on first login, an access key, and permission to assume `roleA` and `roleB`. They do not hold admin rights directly. `roleA` is admin except IAM (`NotAction iam:*` plus an explicit `Deny` on `iam:*`). The deny means another attached policy cannot quietly add IAM. It also means `roleA` cannot `iam:PassRole`. That is deliberate: passing a role is an IAM privilege, and a role that can pass arbitrary roles can escalate. Work that needs `PassRole` gets its own narrow role, which is what the CI policy does.

Trusting `arn:aws:iam::000000000000:root` on `roleC` delegates the decision to Account A. Any principal in Account A whose own policy allows `sts:AssumeRole` on `roleC` can assume it. `roleA` is allowed to call STS, because `sts:AssumeRole` is not an `iam:*` action, so `roleA` could enter Account B directly and skip `roleB`. So could any later policy someone attaches to `engine` or `ci`.

Trusting `arn:aws:iam::000000000000:role/roleB` makes `roleB` the only accepted principal. Account A administrators, `roleA`, and the IAM users fail the trust check even if their identity policy allows the call. Trust and the identity policy are separate checks. Both have to allow the call. `roleB`'s identity policy allows `sts:AssumeRole` on `roleC` only.

I also require an external ID on both sides. The principal ARN is what stops the rest of Account A. The external ID stops a confused-deputy case where some other account is tricked into assuming a role that trusts `roleB`. The sample value in the variables is a placeholder and has to be changed before real use. MFA is required to assume `roleA` and `roleB`, so a stolen access key without the MFA device is not enough to reach either role.

## Task 4 — what the CI policy leaves out

The policy is `policies/ci-pipeline.json`. It is attached only to `ci`, not to `group1`, so `engine` does not inherit it.

It allows the three things the brief asks for:

- Push to `arn:aws:ecr:us-east-1:000000000000:repository/arrise-app`.
- Register a task definition and update `arn:aws:ecs:us-east-1:000000000000:service/arrise-cluster/arrise-service`.
- Read `arrise-build-artifacts`.

Two extra allows exist because those APIs fail without them:

- `ecr:GetAuthorizationToken` on `*`. ECR does not let you scope the authorization token to one repository. Without it, `docker push` cannot log in.
- `iam:PassRole` on `arrise-ecs-execution` and `arrise-ecs-task`, and only when the role is passed to `ecs-tasks.amazonaws.com`. `RegisterTaskDefinition` checks this. The condition and the two ARNs stop `ci` from passing `roleA`, `roleB`, or any other role into a task.

`ecs:RegisterTaskDefinition` and `ecs:DescribeTaskDefinition` are on `*` because those actions do not support a resource ARN. The useful limit is `PassRole`: a task definition is harmless until it can assume a role, and `ci` can only pass those two roles. `ecs:DescribeServices` is included because the deploy call reads the service before it updates it. I assumed an ECS rolling deployment. A CodeDeploy blue/green service would need a different policy, and this one would be wrong for that controller.

S3 writes are an explicit `Deny`, not just a missing `Allow`. A later `Allow` from another policy cannot put, delete, or reconfigure that bucket. `ListBucket` is on the bucket ARN and `GetObject` is on the object ARN, which is the split those actions actually authorize.

Left out, and why:

- `ecr:GetDownloadUrlForLayer`, `BatchGetImage`, `DeleteRepository`, `BatchDeleteImage`, `PutLifecyclePolicy`, `SetRepositoryPolicy`, `CreateRepository`. The pipeline pushes an image to a repository that already exists. It does not pull, create, or delete repositories. A cache that needs pull would be a separate, still-scoped statement.
- `ecs:CreateService`, `DeleteService`, `RunTask`, `StartTask`, `StopTask`, `ExecuteCommand`, `UpdateCluster`, `DeregisterTaskDefinition`, `RegisterContainerInstance`. Deploying one service does not include creating the service, running one-off tasks, opening a shell on a container, or deleting old revisions.
- `s3:ListAllMyBuckets`, `s3:PutObject`, `s3:DeleteObject`, and every bucket other than `arrise-build-artifacts`.
- `iam:CreateUser`, `AttachRolePolicy`, `CreateRole`, `PassRole` on anything except the two ECS roles, and `sts:AssumeRole`. `ci` uses its own credentials. It does not need to hop into `roleA` or `roleB`.
- Secrets Manager, SSM parameters, CloudWatch Logs, EC2, and Lambda. The ECS execution role writes logs and pulls the image. That is the task's privilege, not the pipeline's.

## Task 5 — why the snippet failed

There are two separate bugs.

The trust policy principal is `arn:aws:iam::000000000000:user/roleB`. The `user/` path means an IAM user named `roleB`. `roleB` is a role. When that role calls `sts:AssumeRole`, STS compares the caller with the trust policy. A role session resolves to `arn:aws:iam::000000000000:role/roleB`, which does not match a user ARN, so the call is denied before the identity policy is enough to save it. I trusted `aws_iam_role.role_b.arn`, which is the role ARN, and I did not use an `arn:aws:sts::...:assumed-role/roleB/...` principal. Trust policies have to name the IAM role. STS maps the session back to that role.

The permissions policy is `s3:*` on `Resource = "*"`. That is every S3 action on every bucket in Account B, not full access to one named bucket. The fix allows `s3:*` on the bucket ARN and on `arn:aws:s3:::<name>/*`. Both are required: `ListBucket` and bucket configuration authorize against the bucket ARN, and object actions authorize against the object ARN. The role argument uses `aws_iam_role.role_c.name`. The original `.id` happens to equal the name for this resource, so that was not the failure.

The corrected resources are `aws_iam_role.role_c` and `aws_iam_role_policy.role_c_s3` in `environments/iam/role_c.tf`.
