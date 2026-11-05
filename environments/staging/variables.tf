# Ce fichier déclare les paramètres de la configuration racine.
#
# type        : nature de la valeur attendue.
# description : explication du paramètre.
# default     : valeur utilisée lorsqu'aucune autre valeur n'est fournie.
#
# terraform.tfvars remplace les valeurs par défaut correspondantes.
# Les variables racines sont transmises explicitement aux modules :
# elles ne sont pas automatiquement accessibles dans leurs dossiers.


# Nom utilisé dans les tags et les noms de ressources.
variable "project_name" {
  type        = string
  description = "Nom du projet."
  default     = "moustapha"
}


# Environnement de déploiement.
# Les valeurs dev, staging et prod restent des conventions :
# aucune validation ne limite actuellement les valeurs possibles.
variable "env" {
  type        = string
  description = "Environnement de deploiement : dev, staging ou prod."
  default     = "dev"
}


# Région AWS dans laquelle déployer les ressources.
# Correction : us-east-3 n'est pas une région AWS valide.
#
# Paris correspond aux zones du module VPC et à la paire SSH créée.
variable "region" {
  type        = string
  description = "Region AWS de deploiement."
  default     = "eu-west-3"
}


# AMI Ubuntu vérifiée à Paris lors du déploiement initial.
# Cette AMI utilise l'architecture x86_64.
#
# Une AMI est régionale : changer la région peut nécessiter
# de sélectionner une autre AMI.
variable "aws_ami" {
  type        = string
  description = "Identifiant de l'AMI des instances EC2."
  default     = "ami-001b955040bc46321"
}


# Type utilisé pour les deux instances.
# Correction : t3.micro est le type ayant permis le déploiement.
#
# L'éligibilité Free Tier ne garantit pas la gratuité du projet.
variable "instance_type" {
  type        = string
  description = "Type des instances EC2."
  default     = "t3.micro"
}


# Nom de la paire SSH existante dans AWS, dans la région cible.
# La clé privée correspondante reste sur le poste local.
variable "key_name" {
  type        = string
  description = "Nom de la paire de cles SSH enregistree dans AWS."
  default     = "terraformcloud"
}


# Nom de la base initiale créée dans MySQL.
# Différent du nom de l'instance RDS.
variable "db_name" {
  type        = string
  description = "Nom de la base MySQL initiale."
  default     = "moustaphadb"
}


# Compte administrateur initial de MySQL.
# Un compte applicatif distinct sera créé pour Spring Boot.
variable "db_username" {
  type        = string
  description = "Nom du compte administrateur MySQL."
  default     = "admin"
}


# Mot de passe obligatoire, sans valeur par défaut dans le code.
#
# sensitive masque son affichage habituel.
# Avec l'argument password du module RDS, il reste enregistré
# dans l'état Terraform : cet état doit être protégé.
variable "db_password" {
  type        = string
  description = "Mot de passe du compte administrateur MySQL."
  sensitive   = true
}


# Plages IPv4 autorisées pour SSH.
#
# Liste vide : aucune règle SSH.
# Une adresse suivie de /32 autorise cette seule IPv4 source.
variable "allowed_ssh_cidr" {
  type        = list(string)
  description = "Plages IPv4 autorisees a se connecter en SSH."
  default     = []
}


# Données de démonstration de Yoon (comptes admin, agent, voyageur et départs)
# créées au premier démarrage si la base est vide.
# false en staging : aucune donnée fictive hors du développement.
variable "demo_data" {
  type        = bool
  description = "Cree les donnees de demonstration de Yoon si la base est vide."
  default     = false
}


# Certificat TLS de l'ALB, émis par la PKI EJBCA et importé dans ACM.
#
# Ce n'est pas un secret : seul l'ARN est indiqué ici, la clé privée
# reste dans ACM. Renseigner dans terraform.tfvars :
#   certificate_arn = "arn:aws:acm:eu-west-3:231644789895:certificate/..."
# null : l'ALB reste en HTTP seul.
variable "certificate_arn" {
  type        = string
  default     = null
  description = "ARN du certificat ACM de l'ALB. null : HTTP seul."
}
