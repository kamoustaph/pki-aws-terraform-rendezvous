# ---------------------------------------------------------
# Configuration Terraform
# ---------------------------------------------------------

terraform {
  # Fournisseurs nécessaires au projet.
  required_providers {
    aws = {
      # Fournisseur officiel permettant de gérer les ressources AWS.
      source = "hashicorp/aws"

      # Autorise les versions >= 5.0.0 et < 6.0.0.
      # La version exacte sélectionnée est enregistrée dans
      # le fichier .terraform.lock.hcl.
      version = "~> 5.0"
    }

    # Génère les clés secrètes de l'application Yoon (module app).
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Version minimale de Terraform acceptée par cette configuration.
  # Les exigences des fournisseurs s'appliquent également.
  required_version = ">= 1.3.0"
}


# ---------------------------------------------------------
# Connexion à AWS
# ---------------------------------------------------------

provider "aws" {
  # Région fournie par les variables de la configuration racine.
  region = var.region

  # Profil AWS enregistré sur ton ordinateur.
  # Il utilise les identifiants temporaires de ta session AWS.
  #
  # Cette configuration locale sera adaptée pour GitHub Actions,
  # où ce profil n'existe pas automatiquement.
}


# ---------------------------------------------------------
# Réseau : VPC et sous-réseaux
# ---------------------------------------------------------

module "vpc" {
  # Chemin du module, relatif au dossier de ce fichier.
  source = "../../modules/vpc"

  # Valeurs transmises aux variables d'entrée du module.
  project_name = var.project_name
  env          = var.env

  # Les autres paramètres utilisent les valeurs par défaut
  # déclarées dans modules/vpc/variables.tf :
  # CIDR, sous-réseaux et zones de disponibilité.
}


# ---------------------------------------------------------
# Première instance EC2
# ---------------------------------------------------------

module "ec2-1" {
  # Les deux instances réutilisent le même code de module,
  # mais chaque appel crée sa propre instance.
  source = "../../modules/ec2"

  # Système d'exploitation et taille de l'instance.
  ami           = var.aws_ami
  instance_type = var.instance_type

  # Premier sous-réseau public.
  # Les index commencent à 0.
  subnet_id = module.vpc.public_subnet_ids[0]

  # Nom de la paire de clés déjà enregistrée dans AWS.
  # Ce n'est pas le chemin de la clé privée locale.
  key_name = var.key_name

  # Groupe Web créé par le module Security.
  # Les crochets construisent la liste attendue par le module EC2.
  security_group_ids = [module.security.aws_sg_id]

  project_name = var.project_name
  env          = var.env

  # Application Yoon : Docker + conteneurs api et web (module app).
  # « primary » : cette instance peut créer les données de démonstration.
  user_data            = module.app.user_data["primary"]
  iam_instance_profile = module.app.instance_profile_name
  instance_name        = "ec2-1-${var.project_name}-${var.env}"
}


# ---------------------------------------------------------
# Deuxième instance EC2
# ---------------------------------------------------------

module "ec2-2" {
  source = "../../modules/ec2"

  ami           = var.aws_ami
  instance_type = var.instance_type

  # Deuxième sous-réseau public.
  # Avec les valeurs actuelles du VPC, il est dans l'autre zone.
  subnet_id = module.vpc.public_subnet_ids[1]

  key_name           = var.key_name
  security_group_ids = [module.security.aws_sg_id]

  project_name = var.project_name
  env          = var.env

  # Application Yoon : Docker + conteneurs api et web (module app).
  # « secondary » : jamais de données de démonstration (évite une double insertion).
  user_data            = module.app.user_data["secondary"]
  iam_instance_profile = module.app.instance_profile_name
  instance_name        = "ec2-2-${var.project_name}-${var.env}"
}


# ---------------------------------------------------------
# Application Yoon : secrets SSM, rôle IAM et démarrage des EC2
# ---------------------------------------------------------

module "app" {
  source = "../../modules/app"

  project_name = var.project_name
  env          = var.env
  region       = var.region

  # Connexion de l'API à la base.
  # L'adresse RDS crée une dépendance : les instances démarrent
  # après la création de la base.
  db_host     = module.rds.rds_address
  db_port     = module.rds.rds_port
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # Comptes et départs de démonstration au premier démarrage (dev uniquement).
  demo_data = var.demo_data
}


# ---------------------------------------------------------
# Base de données RDS MySQL
# ---------------------------------------------------------

module "rds" {
  source = "../../modules/rds"

  # RDS utilise les sous-réseaux privés.
  # Le VPC est déterminé par ces sous-réseaux :
  # aucune entrée vpc_id n'est nécessaire dans ce module.
  subnet_ids = module.vpc.private_subnet_ids

  # Groupe autorisant MySQL depuis les serveurs Web.
  security_group_id = module.security.rds_sg_id

  # Base initiale et identifiants administrateur.
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  project_name = var.project_name
  env          = var.env
}


# ---------------------------------------------------------
# Groupes et règles de sécurité
# ---------------------------------------------------------

module "security" {
  source = "../../modules/security"

  # Tous les groupes sont créés dans le VPC du projet.
  vpc_id = module.vpc.vpc_id

  project_name = var.project_name
  env          = var.env

  # Plages autorisées à accéder au port SSH des instances.
  # Une liste vide ne crée aucune règle SSH.
  allowed_ssh_cidr = var.allowed_ssh_cidr
}


# ---------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------

module "alb" {
  source = "../../modules/alb"

  vpc_id = module.vpc.vpc_id

  # L'ALB public est placé dans les sous-réseaux publics.
  subnet_ids = module.vpc.public_subnet_ids

  # Groupe de sécurité propre à l'ALB.
  security_group_id = module.security.alb_sg_id

  # Enregistre les deux instances dans le groupe cible.
  instance_ids = [
    module.ec2-1.instance_id,
    module.ec2-2.instance_id,
  ]

  project_name = var.project_name
  env          = var.env
}


# Les références module.xxx.sortie créent des dépendances implicites.
# Terraform utilise ces dépendances pour déterminer l'ordre des actions.
#
# L'ordre des blocs dans ce fichier n'impose pas l'ordre de création.
# Par exemple, Security peut apparaître après EC2 dans le texte,
# tout en étant créé avant les instances.
