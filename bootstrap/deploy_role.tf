# ---------------------------------------------------------
# Rôle de déploiement des applications (backend et frontend)
# ---------------------------------------------------------
#
# Distinct de github-actions-role (Terraform, droits très larges) :
# ce rôle peut seulement
#   1. pousser des images dans les 2 registres ECR ;
#   2. demander aux EC2 du projet, via SSM, de lancer le script de déploiement.
# Il ne peut ni créer ni détruire d'infrastructure.

locals {
  github_owner = "kamoustaph@162557925"

  # Dépôts autorisés, branche main uniquement.
  # Deux formats de "sub" sont acceptés : avec identifiants numériques
  # (format immuable, celui de ton compte) et sans, au cas où un dépôt
  # utilise encore le format classique.
  app_repos = ["GestionVoyageBakend", "GestionVoyageFrontend"]

  deploy_allowed_subs = flatten([
    for repo in local.app_repos : [
      "repo:${local.github_owner}/${repo}@*:ref:refs/heads/main",
      "repo:kamoustaph/${repo}:ref:refs/heads/main",
    ]
  ])
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "app_deploy" {
  name = "yoon-app-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          # StringLike pour accepter le joker * sur l'identifiant du dépôt.
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.deploy_allowed_subs
          }
        }
      }
    ]
  })

  tags = {
    Name = "yoon-app-deploy-role"
  }
}

resource "aws_iam_role_policy" "app_deploy" {
  name = "yoon-app-deploy-policy"
  role = aws_iam_role.app_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeImages"
        ]
        Resource = [for r in aws_ecr_repository.app : r.arn]
      },
      {
        Sid      = "TrouverLesInstances"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        # Le document AWS-RunShellScript exécute une commande sur l'instance.
        Sid      = "DocumentDeDeploiement"
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ssm:${data.aws_region.current.name}::document/AWS-RunShellScript"
      },
      {
        # ... mais uniquement sur les instances du projet (tag Project=moustapha).
        Sid      = "InstancesDuProjet"
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"
        Condition = {
          StringEquals = {
            "ssm:resourceTag/Project" = "moustapha"
          }
        }
      },
      {
        Sid    = "SuivreLeDeploiement"
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations",
          "ssm:DescribeInstanceInformation"
        ]
        Resource = "*"
      }
    ]
  })
}
