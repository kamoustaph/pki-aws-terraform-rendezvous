# AMI utilisée pour créer l'instance.
#
# L'AMI doit :
# - exister dans la région du fournisseur AWS ;
# - être compatible avec l'architecture du type d'instance ;
# - correspondre au système souhaité, par exemple Ubuntu.
variable "ami" {
  type        = string
  description = "Identifiant de l'AMI pour l'instance EC2."
}


# Taille de l'instance.
# Valeur conservée depuis ton code initial.
#
# Vérifier sa disponibilité, sa compatibilité avec l'AMI
# et son coût avant le déploiement.
variable "instance_type" {
  type        = string
  description = "Type d'instance EC2."
  default     = "t2.micro"
}


# Sous-réseau dans lequel placer l'instance.
#
# Un sous-réseau privé ne fournit pas d'accès SSH direct depuis Internet.
# Un sous-réseau public nécessite aussi une IPv4 publique,
# une route Internet et une règle SSH adaptée.
variable "subnet_id" {
  type        = string
  description = "Identifiant du sous-reseau de l'instance EC2."
}


# Groupes de sécurité à associer à l'instance.
# Ils doivent appartenir au même VPC que le sous-réseau.
variable "security_group_ids" {
  type        = list(string)
  description = "Identifiants des groupes de securite de l'instance EC2."

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "Fournir au moins un groupe de securite."
  }
}


# Nom de la paire de clés ENREGISTRÉE dans AWS.
#
# Ce n'est ni le contenu de la clé privée ni son chemin local.
# La paire doit exister dans la région où l'instance sera créée.
variable "key_name" {
  type        = string
  description = "Nom de la paire de cles SSH enregistree dans AWS."
  default     = "terraformcloud"
}


# Compte Linux utilisé pour la connexion SSH.
#
# ubuntu correspond à une AMI Ubuntu.
# Pour Amazon Linux, utiliser généralement ec2-user.
variable "ssh_user" {
  type        = string
  description = "Utilisateur SSH correspondant a l'AMI."
  default     = "ubuntu"
}


# Chemin de la clé PRIVÉE sur ton ordinateur.
#
# Utilisé uniquement pour afficher une commande SSH.
# Terraform ne lit pas ce fichier et ne l'envoie pas à AWS.
#
# Le chemin relatif suppose que tu exécutes SSH depuis
# la racine du projet.
variable "private_key_path" {
  type        = string
  description = "Chemin local de la cle privee pour la commande SSH."
  default     = "./key/terraformcloud.pem"
}


# Environnement utilisé dans les tags.
variable "env" {
  type        = string
  description = "Environnement de l'instance EC2."
  default     = "dev"
}


# Nom du projet utilisé dans les tags.
variable "project_name" {
  type        = string
  description = "Nom du projet."
  default     = "moustapha"
}


variable "user_data" {
  type        = string
  description = "Script d'initialisation de l'instance EC2."
}


# ---------------------------------------------------------
# Variables ajoutées pour le déploiement de Yoon
# Toutes ont une valeur par défaut : les appels existants
# du module restent valides sans modification.
# ---------------------------------------------------------

# Profil d'instance IAM attaché à l'EC2.
# null : aucun rôle (comportement d'origine).
variable "iam_instance_profile" {
  type        = string
  description = "Nom du profil d'instance IAM ; null pour aucun."
  default     = null
}

# Taille du disque système en Go.
variable "root_volume_size" {
  type        = number
  description = "Taille du disque systeme en Go."
  default     = 16
}

# Nom affiché dans la console (tag Name).
# null : nom d'origine ec2-<projet>-<env>.
variable "instance_name" {
  type        = string
  description = "Tag Name de l'instance ; null pour le nom par defaut."
  default     = null
}
