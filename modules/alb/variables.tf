# Nom du projet utilisé dans les noms et les tags.
variable "project_name" {
  type        = string
  default     = "moustapha"
  description = "Nom du projet pour le nommage des ressources."
}


# Environnement utilisé dans les noms et les tags.
variable "env" {
  type        = string
  default     = "dev"
  description = "Environnement pour le nommage des ressources."
}


# VPC contenant le groupe cible et les instances applicatives.
variable "vpc_id" {
  type        = string
  description = "Identifiant du VPC du groupe cible."
}


# Groupe de sécurité associé à l'ALB.
#
# Il doit autoriser :
# - les connexions clientes vers le listener ;
# - les connexions sortantes vers les instances sur le port 80.
#
# Ce n'est pas le groupe RDS ni celui des instances Web.
variable "security_group_id" {
  type        = string
  description = "Identifiant du groupe de securite ALB."
}


# Instances EC2 à enregistrer dans le groupe cible.
#
# Enregistrer une instance ne suffit pas à la rendre opérationnelle :
# un service HTTP doit écouter sur son port 80.
variable "instance_ids" {
  type        = list(string)
  description = "Identifiants des instances EC2 cibles de l'ALB."
}


# Sous-réseaux publics dans lesquels placer l'ALB.
#
# Pour cette architecture régionale classique :
# fournir au moins deux sous-réseaux dans deux zones différentes.
# Les sous-réseaux doivent appartenir au VPC indiqué.
variable "subnet_ids" {
  type        = list(string)
  description = "Identifiants des sous-reseaux publics de l'ALB."

  # Vérifie le nombre de sous-réseaux distincts.
  # Cette validation ne vérifie pas leurs zones ni leur routage.
  validation {
    condition     = length(distinct(var.subnet_ids)) >= 2
    error_message = "Fournir au moins deux sous-reseaux publics dans des zones differentes."
  }
}