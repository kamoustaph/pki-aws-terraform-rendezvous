
variable "env" {

  type        = string
  description = "Envionnement (dev, staging, prod)"
  default     = "dev"

}

variable "project_name" {
  type        = string
  description = "Project name"
  default     = "moustapha"

}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block pour le VPC"
  default     = "10.0.0.0/16"

}

variable "public_subnet_cidr" {
  type        = list(string)
  description = "CIDR block pour les sous-réseaux publics"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidr" {
  type        = list(string)
  description = "CIDR block pour le sous-réseau privé"
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}


variable "availability_zones" {
  type        = list(string)
  description = "Zones de disponibilité"
  default     = ["eu-west-3a", "eu-west-3b"]
}
