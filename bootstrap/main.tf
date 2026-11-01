# Fournisseur utilisé pour créer et configurer le bucket S3.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"

      # Fixe exactement la version du provider AWS.
      # Cette version est indépendante de celle du logiciel Terraform.
      version = "5.0.0"
    }
  }
}

# Région dans laquelle le bucket sera créé.
# Les identifiants sont récupérés depuis la configuration AWS
# du terminal ou les variables d'environnement de GitHub Actions.
provider "aws" {
  region = "eu-west-3"
}

# Bucket partagé pour conserver les states des environnements.
#
# Le state associe les ressources du code Terraform à leurs
# identifiants réels dans AWS. Il permet aux exécutions suivantes
# de retrouver les ressources déjà créées.
#
# Ce bucket est géré séparément dans le dossier bootstrap :
# détruire dev, staging ou prod ne doit pas supprimer ce bucket.
#
# Le nom du bucket doit être unique parmi les buckets S3
# de la partition AWS utilisée.
resource "aws_s3_bucket" "terraform_bucket" {
  bucket = "terraform-bucket-moustapha-2026"

  # Étiquettes descriptives du bucket.
  # Le tag Environment ne limite pas son utilisation à dev.
  tags = {
    Name        = "terraform-state-moustapha"
    Environment = "Dev"
  }
}

# Active le versionnement des objets.
#
# Chaque modification du state conserve sa version précédente,
# ce qui facilite une récupération en cas d'erreur.
# La restauration d'une version reste une opération manuelle.
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Configure le chiffrement par défaut des objets stockés.
#
# AES256 correspond à SSE-S3 :
# Amazon S3 gère les clés de chiffrement.
#
# Le chiffrement protège les données stockées ; les permissions
# IAM déterminent qui peut les lire ou les modifier.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Empêche l'exposition publique du bucket.
#
# Les states peuvent contenir des données sensibles :
# ils ne doivent pas être accessibles publiquement.
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_bucket.id

  # Refuse les nouvelles ACL donnant un accès public.
  block_public_acls = true

  # Refuse les nouvelles politiques de bucket publiques.
  block_public_policy = true

  # Ignore les autorisations publiques des ACL existantes.
  ignore_public_acls = true

  # Restreint les accès lorsqu'une politique publique existe.
  restrict_public_buckets = true
}

# Aucun backend distant n'est déclaré dans ce bootstrap.
# Son propre state reste donc local avec cette configuration.
#
# Conserver une sauvegarde sécurisée de bootstrap/terraform.tfstate.
# Ne pas publier ce fichier dans Git.