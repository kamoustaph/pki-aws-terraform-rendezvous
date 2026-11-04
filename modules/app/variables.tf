# Nom utilisé dans les tags et les noms de ressources.
variable "project_name" {
  type        = string
  description = "Nom du projet."
  default     = "moustapha"
}

# Environnement : dev, staging ou prod.
# Sert de préfixe aux paramètres SSM : /yoon/<env>/...
variable "env" {
  type        = string
  description = "Environnement de deploiement."
}

variable "region" {
  type        = string
  description = "Region AWS (registre ECR et parametres SSM)."
}

# Registres ECR créés dans le bootstrap.
variable "api_repository" {
  type        = string
  description = "Nom du registre ECR de l'API."
  default     = "gestion-voyage-api"
}

variable "web_repository" {
  type        = string
  description = "Nom du registre ECR du frontend."
  default     = "gestion-voyage-web"
}

# Tag d'image lancé au premier démarrage des instances.
# Les déploiements suivants passent le tag voulu au script deploy.sh.
variable "image_tag" {
  type        = string
  description = "Tag d'image utilise au premier demarrage."
  default     = "latest"
}

# Connexion à la base RDS.
variable "db_host" {
  type        = string
  description = "Nom DNS de l'instance RDS, sans le port."
}

variable "db_port" {
  type        = number
  description = "Port MySQL."
  default     = 3306
}

variable "db_name" {
  type        = string
  description = "Nom de la base MySQL."
}

variable "db_username" {
  type        = string
  description = "Compte MySQL utilise par l'API."
}

variable "db_password" {
  type        = string
  description = "Mot de passe MySQL (stocke dans SSM en SecureString)."
  sensitive   = true
}

# Données de démonstration (comptes et départs) créées si la base est vide.
# Seule l'instance « primary » les crée, pour éviter deux insertions simultanées.
variable "demo_data" {
  type        = bool
  description = "Cree les donnees de demonstration au premier demarrage."
  default     = false
}

# Origines autorisées en CORS, séparées par des virgules.
# Vide : inutile tant que le site et l'API sont servis par le même ALB.
variable "cors_allowed_origins" {
  type        = string
  description = "Origines CORS supplementaires ; vide si meme domaine."
  default     = ""
}

# Mémoire maximale de la JVM. 384m convient à une instance t3.micro (1 Go).
variable "java_max_heap" {
  type        = string
  description = "Option -Xmx de la JVM de l'API."
  default     = "384m"
}
