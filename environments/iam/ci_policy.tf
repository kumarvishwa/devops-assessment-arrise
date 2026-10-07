locals {
  ci_policy_json = file("${path.module}/../../policies/ci-pipeline.json")
  ci_policy      = jsondecode(local.ci_policy_json)

  ecr_repository_arn  = "arn:aws:ecr:${var.aws_region}:${var.account_a_id}:repository/${var.ecr_repository_name}"
  ecs_service_arn     = "arn:aws:ecs:${var.aws_region}:${var.account_a_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}"
  artifact_bucket_arn = "arn:aws:s3:::${var.artifact_bucket_name}"
  execution_role_arn  = "arn:aws:iam::${var.account_a_id}:role/${var.ecs_execution_role_name}"
  task_role_arn       = "arn:aws:iam::${var.account_a_id}:role/${var.ecs_task_role_name}"
}

resource "aws_iam_policy" "ci_pipeline" {
  name        = "ci-pipeline-least-privilege"
  description = "Push one ECR repository, deploy one ECS service, and read one artifact bucket."
  policy      = local.ci_policy_json

  lifecycle {
    precondition {
      condition = alltrue([
        can(regex(local.ecr_repository_arn, local.ci_policy_json)),
        can(regex(local.ecs_service_arn, local.ci_policy_json)),
        can(regex(local.artifact_bucket_arn, local.ci_policy_json)),
        can(regex(local.execution_role_arn, local.ci_policy_json)),
        can(regex(local.task_role_arn, local.ci_policy_json)),
        local.ci_policy.Version == "2012-10-17",
      ])
      error_message = "policies/ci-pipeline.json does not match the CI variables in this stack."
    }
  }
}

resource "aws_iam_user_policy_attachment" "ci" {
  user       = aws_iam_user.programmatic["ci"].name
  policy_arn = aws_iam_policy.ci_pipeline.arn
}
