# Les outputs exposent les résultats de la configuration racine.
# Ils peuvent être consultés après déploiement avec :
#
# terraform output
#
# Ils ne créent aucune ressource AWS.


# Identifiant du VPC retourné par le module réseau.
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "Identifiant du VPC du projet."
}


# Endpoint RDS comprenant le nom DNS et le port MySQL.
# Cette valeur n'inclut pas le mot de passe.
output "rds_endpoint" {
  value       = module.rds.rds_endpoint
  description = "Endpoint de connexion RDS au format adresse:port."
}


# Regroupe les informations des deux instances dans un seul objet.
output "ec2_instances" {
  description = "Informations reseau et commandes SSH des instances EC2."

  value = {
    ec2_1 = {
      # Nom du champ à gauche ; sortie exacte du module à droite.
      public_ip = module.ec2-1.ec2_public_ip

      # Adresse utilisée pour les communications internes au VPC.
      private_ip = module.ec2-1.ec2_private_ip

      public_dns  = module.ec2-1.public_dns
      private_dns = module.ec2-1.private_dns

      # Commande indicative utilisant le chemin de clé privé local.
      # Le contenu de la clé n'est pas exposé.
      ssh = module.ec2-1.ssh_command
    }

    ec2_2 = {
      public_ip   = module.ec2-2.ec2_public_ip
      private_ip  = module.ec2-2.ec2_private_ip
      public_dns  = module.ec2-2.public_dns
      private_dns = module.ec2-2.private_dns
      ssh         = module.ec2-2.ssh_command
    }
  }
}


# URL HTTP utilisée par les visiteurs pour joindre l'ALB.
# Le listener actuel ne fournit pas encore HTTPS.
output "load_balancer_url" {
  value       = module.alb.url_alb
  description = "URL HTTP de l'application via l'ALB."
}


# Identifiants des sous-réseaux publics.
output "public_subnet_ids" {
  value       = module.vpc.public_subnet_ids
  description = "Identifiants des sous-reseaux publics."
}