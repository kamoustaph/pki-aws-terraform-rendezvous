terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.0.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}

# Bucket qui conservera les fichiers de state Terraform.
resource "aws_s3_bucket" "terraform_bucket" {
  bucket = "terraform-bucket-moustapha-2026"

  tags = {
    Name        = "terraform-state-moustapha"
    Environment = "Dev"
  }
}

# Conserve les anciennes versions des fichiers de state.
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Chiffrement des objets avec les clés gérées par Amazon S3.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloque les accès publics au bucket.
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}