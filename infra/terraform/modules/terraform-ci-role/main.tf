data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Three distinct sub claim shapes, one per job type in infra.yml:
    # - "pull_request" for the plan job (no environment/ref)
    # - "ref:..." would apply to a push-triggered job with no `environment:`
    # - "environment:..." for the apply job, which declares `environment:
    #   infra-${matrix.environment}` for approval gating -- that changes the
    #   token's sub claim shape entirely, so it needs its own condition value
    #   rather than falling under the ref-based one above.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:${var.github_ref}",
        "repo:${var.github_repo}:pull_request",
        "repo:${var.github_repo}:environment:${var.github_environment}",
      ]
    }
  }
}

resource "aws_iam_role" "terraform_ci" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

# Scoped to exactly what modules/vpc, modules/eks, modules/ecr, and
# modules/github-oidc manage. EC2/EKS/Autoscaling/KMS actions are left at
# resource "*" because most of their create calls don't support resource-level
# ARNs before the resource exists; IAM and ECR are scoped by naming convention
# since those DO support it, which also keeps PassRole from being a privilege
# escalation path to unrelated roles in the account.
data "aws_iam_policy_document" "terraform_ci" {
  statement {
    sid    = "TerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket_name}",
      "arn:aws:s3:::${var.state_bucket_name}/*",
    ]
  }

  statement {
    sid    = "TerraformLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = ["arn:aws:dynamodb:*:*:table/${var.lock_table_name}"]
  }

  statement {
    sid       = "Networking"
    effect    = "Allow"
    actions   = ["ec2:*"]
    resources = ["*"]
  }

  statement {
    sid       = "Eks"
    effect    = "Allow"
    actions   = ["eks:*"]
    resources = ["*"]
  }

  statement {
    sid       = "NodeGroupAutoscaling"
    effect    = "Allow"
    actions   = ["autoscaling:*"]
    resources = ["*"]
  }

  statement {
    sid       = "ClusterEncryptionKms"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid       = "Ecr"
    effect    = "Allow"
    actions   = ["ecr:*"]
    resources = ["arn:aws:ecr:*:*:repository/${var.project}-backend-*"]
  }

  statement {
    sid    = "IamManageProjectRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListInstanceProfilesForRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:ListPolicyVersions",
    ]
    resources = concat(
      [
        "arn:aws:iam::*:role/${var.project}-eks-*",
        "arn:aws:iam::*:instance-profile/${var.project}-eks-*",
        "arn:aws:iam::*:policy/${var.project}-eks-*",
      ],
      var.additional_managed_role_arns,
    )
  }

  # The EKS module manages a CloudWatch Log Group for cluster control plane
  # logs, named by cluster_name so this stays within the ${project}-eks-*
  # blast radius the rest of this policy also scopes to.
  statement {
    sid    = "EksClusterLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:ListTagsForResource",
    ]
    resources = ["arn:aws:logs:*:*:log-group:/aws/eks/${var.project}-eks-*"]
  }

  # DescribeLogGroups is a list/discovery action -- CloudWatch Logs doesn't
  # support authorizing it against a specific log group ARN (the API takes
  # an optional name *prefix* to filter results after the fact, not as part
  # of the IAM resource match), so unlike every other statement here this
  # one can't be scoped tighter than "*".
  statement {
    sid       = "EksClusterLoggingDiscovery"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid    = "IamManageOidcProvider"
    effect = "Allow"
    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
    ]
    resources = ["arn:aws:iam::*:oidc-provider/token.actions.githubusercontent.com"]
  }

  statement {
    sid       = "PassProjectRolesOnly"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::*:role/${var.project}-eks-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "eks.amazonaws.com",
        "ec2.amazonaws.com",
      ]
    }
  }

  statement {
    sid       = "CallerIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "terraform_ci" {
  name   = "terraform-ci"
  role   = aws_iam_role.terraform_ci.id
  policy = data.aws_iam_policy_document.terraform_ci.json
}
