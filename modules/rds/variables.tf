# Environnement utilisé dans les noms et les tags des ressources.
variable "env" {
  type        = string
  description = "Environnement (dev, staging, prod)."
  default     = "dev"
}


# Nom du projet utilisé pour identifier les ressources.
variable "project_name" {
  type        = string
  description = "Nom du projet."
  default     = "moustapha"
}


# Groupe de sécurité qui sera associé à l'instance RDS.
#
# Il doit appartenir au même VPC que les sous-réseaux fournis.
# Pour MySQL, il doit autoriser le port 3306 depuis le groupe
# des serveurs applicatifs.
variable "security_group_id" {
  type        = string
  description = "Identifiant du groupe de securite RDS."
}


# Sous-réseaux dans lesquels RDS pourra placer l'instance.
#
# Fournir les sous-réseaux privés du module VPC.
# Ils doivent appartenir au même VPC et couvrir au moins deux zones.
variable "subnet_ids" {
  type        = list(string)
  description = "Identifiants des sous-reseaux prives pour RDS."

  # Vérifie uniquement le nombre d'identifiants distincts.
  # Cette validation ne vérifie pas leurs zones ni leur VPC.
  validation {
    condition     = length(distinct(var.subnet_ids)) >= 2
    error_message = "Fournir au moins deux sous-reseaux distincts couvrant deux zones."
  }
}


# Nom de la base initiale créée dans l'instance MySQL.
#
# Ce nom est différent de l'identifiant de l'instance RDS.
# L'underscore de l'ancienne valeur est retiré pour respecter
# les contraintes du nom initial de base RDS MySQL.
variable "db_name" {
  type        = string
  description = "Nom de la base MySQL initiale."
  default     = "moustaphadb"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{0,63}$", var.db_name))
    error_message = "Utiliser 1 a 64 caracteres alphanumeriques, en commencant par une lettre."
  }
}


# Compte administrateur initial de la base.
#
# Ce compte sert à l'administration et à la préparation de la base.
# L'application devra ensuite utiliser un compte dédié
# avec uniquement les permissions nécessaires.
variable "db_username" {
  type        = string
  description = "Nom du compte administrateur MySQL."
  default     = "admin"
}


# Mot de passe obligatoire : aucune valeur secrète par défaut.
#
# sensitive masque son affichage habituel dans Terraform.
# Cela ne supprime pas sa présence dans l'état Terraform
# lorsque l'argument password est utilisé.
variable "db_password" {
  type        = string
  description = "Mot de passe du compte administrateur MySQL."
  sensitive   = true
  nullable    = false

  # Première vérification de longueur.
  # AWS vérifie également les caractères autorisés.
  validation {
    condition = (
      length(var.db_password) >= 8 &&
      length(var.db_password) <= 41
    )

    error_message = "Le mot de passe MySQL doit contenir entre 8 et 41 caracteres."
  }
}