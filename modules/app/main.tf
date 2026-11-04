# ---------------------------------------------------------
# Module app : ce dont les EC2 ont besoin pour faire tourner Yoon
# ---------------------------------------------------------
#
# 1. Secrets et paramètres dans SSM Parameter Store (/yoon/<env>/...).
# 2. Rôle IAM des instances : lire ces paramètres, tirer les images ECR,
#    recevoir les commandes SSM de déploiement.
# 3. Script de démarrage (user data) : installe Docker et lance
#    les conteneurs « api » et « web ».
#
# Ce module ne crée aucune instance : il fournit le profil IAM
# et le user data au module ec2.

data "aws_caller_identity" "current" {}

locals {
  prefix   = "/yoon/${var.env}"
  registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
  name     = "yoon-${var.env}"
}

# ---------------------------------------------------------
# Secrets de l'application
# ---------------------------------------------------------

# Clé de signature des jetons de connexion (JWT).
# La changer déconnecte tous les utilisateurs.
resource "random_password" "jwt" {
  length  = 64
  special = false
}

# Clé de signature des QR codes des billets.
# La changer invalide tous les billets déjà émis.
resource "random_password" "qr" {
  length  = 48
  special = false
}

# SecureString : chiffré avec la clé KMS gérée par AWS (aws/ssm).
# Les valeurs restent aussi dans le state Terraform, qui doit rester protégé.
resource "aws_ssm_parameter" "secure" {
  for_each = {
    db_password = var.db_password
    jwt_secret  = random_password.jwt.result
    qr_secret   = random_password.qr.result
  }

  name  = "${local.prefix}/${each.key}"
  type  = "SecureString"
  value = each.value

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}

# Paramètres non sensibles.
resource "aws_ssm_parameter" "plain" {
  for_each = {
    db_url               = "jdbc:mysql://${var.db_host}:${var.db_port}/${var.db_name}?sslMode=PREFERRED"
    db_username          = var.db_username
    demo_data            = tostring(var.demo_data)
    cors_allowed_origins = var.cors_allowed_origins == "" ? "none" : var.cors_allowed_origins
    java_max_heap        = var.java_max_heap
  }

  name  = "${local.prefix}/${each.key}"
  type  = "String"
  value = each.value

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}

# ---------------------------------------------------------
# Rôle IAM des instances
# ---------------------------------------------------------

resource "aws_iam_role" "ec2" {
  name = "${local.name}-ec2-role"

  # Seul le service EC2 peut endosser ce rôle (pour le compte de l'instance).
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name}-ec2-role"
    Project     = var.project_name
    Environment = var.env
  }
}

# Agent SSM : permet les commandes de déploiement et Session Manager
# (connexion à l'instance depuis la console, sans SSH).
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Lecture seule sur ECR : docker pull des images.
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Lecture des paramètres de CET environnement uniquement.
resource "aws_iam_role_policy" "read_params" {
  name = "${local.name}-read-params"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${local.prefix}/*"
      },
      {
        # Déchiffrement des SecureString, seulement à travers SSM.
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = "*"
        Condition = {
          StringEquals = { "kms:ViaService" = "ssm.${var.region}.amazonaws.com" }
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ---------------------------------------------------------
# Script de démarrage des instances
# ---------------------------------------------------------
#
# Deux variantes : « primary » peut créer les données de démonstration,
# « secondary » jamais (une seule insertion dans la base).

locals {
  user_data = {
    for role in ["primary", "secondary"] : role => templatefile("${path.module}/user_data.sh.tftpl", {
      env            = var.env
      region         = var.region
      registry       = local.registry
      api_repository = var.api_repository
      web_repository = var.web_repository
      image_tag      = var.image_tag
      instance_role  = role
      deploy_script  = file("${path.module}/deploy.sh")
    })
  }
}
