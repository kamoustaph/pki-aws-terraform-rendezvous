# Environnement utilisé dans les noms des groupes de sécurité.
# Exemple : web-sg-moustapha-dev.
variable "env" {
  type        = string
  description = "Environnement (dev, staging, prod)"
  default     = "dev"
}


# Nom du projet utilisé pour identifier les ressources.
variable "project_name" {
  type        = string
  description = "Nom du projet"
  default     = "moustapha"
}


# Identifiant du VPC dans lequel créer les groupes de sécurité.
#
# Cette variable n'a pas de valeur par défaut :
# le module appelant doit obligatoirement la fournir.
#
# Exemple dans le module racine :
# vpc_id = module.vpc.vpc_id
variable "vpc_id" {
  type        = string
  description = "Identifiant du VPC"
}


# Plages IPv4 autorisées à se connecter en SSH aux serveurs Web.
#
# Liste vide : aucune règle SSH n'est créée.
# Pour autoriser ton poste, fournis son IPv4 publique suivie de /32.
#
# La valeur 0.0.0.0/0 autoriserait toutes les adresses IPv4.
# Elle n'est donc plus utilisée comme valeur par défaut.
#
# Une règle SSH n'établit pas de chemin réseau :
# pour une instance privée, un accès VPN, bastion ou autre mécanisme
# d'administration reste nécessaire.
variable "allowed_ssh_cidr" {
  type        = list(string)
  description = "Liste des plages IPv4 autorisées pour SSH ; vide pour désactiver cet accès"
  default     = []

  # Vérifie que chaque élément est une plage CIDR IPv4 valide.
  validation {
    condition = alltrue([
      for cidr in var.allowed_ssh_cidr :
      can(cidrnetmask(cidr))
    ])

    error_message = "Chaque valeur doit être un CIDR IPv4 valide."
  }
}