terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Génère les clés secrètes de l'application (JWT, QR).
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
