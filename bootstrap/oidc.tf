# Fournisseur permettant à AWS de vérifier les jetons GitHub Actions.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name = "github-actions-oidc"
  }
}

# Rôle utilisé par GitHub Actions avec des identifiants temporaires.
resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"

  # Détermine quelles identités GitHub peuvent utiliser ce rôle.
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

            # Format réellement envoyé par GitHub pour ce dépôt.
            # Les identifiants numériques font partie du sujet.
            "token.actions.githubusercontent.com:sub" = [
              "repo:kamoustaph@162557925/pki-aws-terraform-rendezvous@1433162106:pull_request",
              "repo:kamoustaph@162557925/pki-aws-terraform-rendezvous@1433162106:environment:dev",
              "repo:kamoustaph@162557925/pki-aws-terraform-rendezvous@1433162106:environment:staging",
              "repo:kamoustaph@162557925/pki-aws-terraform-rendezvous@1433162106:environment:prod",
              "repo:kamoustaph@162557925/pki-aws-terraform-rendezvous@1433162106:ref:refs/heads/main"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "github-actions-role"
  }
}

# Détermine les opérations AWS autorisées après la connexion.
# Permissions actuelles du laboratoire, conservées ici.
# Elles sont larges et pourront être limitées séparément.
resource "aws_iam_role_policy" "github_actions" {
  name = "github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ec2:*",
          "rds:*",
          "vpc:*",
          "elasticloadbalancing:*",
          "s3:*",
          "dynamodb:*",
          "iam:*",
          # Ajouts pour le déploiement de Yoon (étape 2) :
          # paramètres SSM (secrets de l'application) et lecture ECR.
          "ssm:*",
          "ecr:*"
        ]

        Resource = "*"
      }
    ]
  })
}
