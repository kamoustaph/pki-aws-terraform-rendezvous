# Ce fichier déclare les paramètres d'entrée du module VPC.
#
# Pour chaque variable :
# - type        : indique le type de valeur accepté.
# - description : explique à quoi sert la variable.
# - default     : valeur utilisée si le module appelant n'en fournit pas.
#
# Dans main.tf, une variable se lit avec : var.nom_de_la_variable.


# Environnement auquel appartient l'infrastructure.
# Dans ton module, cette valeur sert à construire les noms des ressources.
# Exemple : avec env = "dev", les noms se terminent par "-dev".
#
# Attention : "dev", "staging" et "prod" sont des conventions.
# Sans bloc de validation, Terraform accepte aussi d'autres textes.
variable "env" {
  type        = string
  description = "Environnement (dev, staging, prod)"
  default     = "dev"
}


# Nom du projet, utilisé dans les tags Name des ressources AWS.
#
# Avec project_name = "moustapha" et env = "dev",
# le VPC reçoit le tag Name : "vpc-moustapha-dev".
#
# Cette variable sert au nommage ; elle ne crée pas de ressource à elle seule.
variable "project_name" {
  type        = string
  description = "Project name"
  default     = "moustapha"
}


# Plage d'adresses IP privées du VPC, écrite au format CIDR.
# Le VPC constitue le réseau qui contient tes sous-réseaux.
#
# "10.0.0.0/16" couvre les adresses de 10.0.0.0 à 10.0.255.255.
# Les plages des sous-réseaux doivent être incluses dans cette plage
# et ne doivent pas se chevaucher.
variable "vpc_cidr" {
  type        = string
  description = "CIDR block pour le VPC"
  default     = "10.0.0.0/16"
}


# Liste des plages IP des sous-réseaux publics.
# list(string) signifie : une liste dont chaque élément est un texte.
#
# Ton main.tf utilise la longueur de cette liste pour déterminer
# combien de sous-réseaux publics créer : ici, deux.
#
# Index 0 : 10.0.1.0/24, associé à availability_zones[0].
# Index 1 : 10.0.2.0/24, associé à availability_zones[1].
#
# Un /24 contient 256 adresses au total.
# AWS réserve 5 adresses dans chaque sous-réseau IPv4.
#
# Le caractère public vient de la route vers l'Internet Gateway,
# configurée dans main.tf, pas du nom de cette variable.
variable "public_subnet_cidr" {
  type        = list(string)
  description = "CIDR block pour les sous-réseaux publics"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}


# Liste des plages IP des sous-réseaux privés.
# Ton main.tf crée ici deux sous-réseaux privés.
#
# Index 0 : 10.0.3.0/24, associé à availability_zones[0].
# Index 1 : 10.0.4.0/24, associé à availability_zones[1].
#
# Dans ton architecture, leur route par défaut passe par la NAT Gateway :
# elle permet les connexions IPv4 sortantes vers Internet et leurs réponses,
# sans permettre des connexions entrantes initiées depuis Internet.
#
# Les règles de sécurité doivent également autoriser les communications.
variable "private_subnet_cidr" {
  type        = list(string)
  description = "CIDR block pour le sous-réseau privé"
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}


# Zones de disponibilité dans lesquelles créer les sous-réseaux.
# Une zone est une partie isolée de l'infrastructure d'une région AWS.
# Ces deux zones appartiennent à la région Paris : eu-west-3.
#
# Avec ton main.tf et les listes ci-dessus :
# - eu-west-3a accueille le premier sous-réseau public et le premier privé.
# - eu-west-3b accueille le deuxième sous-réseau public et le deuxième privé.
#
# Le fournisseur AWS doit être configuré dans la région correspondante.
#
# Attention : main.tf utilise les index des listes.
# La liste des zones doit donc contenir au moins autant d'éléments
# que chacune des listes de sous-réseaux.
variable "availability_zones" {
  type        = list(string)
  description = "Zones de disponibilité"
  default     = ["eu-west-3a", "eu-west-3b"]
}