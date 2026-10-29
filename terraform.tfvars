# Région cible : Europe Paris.
region = "eu-west-3"

# AMI Ubuntu x86_64 utilisée pour les deux instances.
aws_ami = "ami-001b955040bc46321"

# Type d'instance accepté lors du déploiement.
instance_type = "t3.micro"

# Nom de la paire de clés existante à Paris.
key_name = "terraformcloud"

# Base initiale et compte administrateur.
db_name     = "moustaphadb"
db_username = "admin"
db_password      = "admin123"
# Le mot de passe est fourni séparément.
# Sans autre source, Terraform le demandera lors du plan ou de l'apply.
# Pour l'infrastructure existante, fournir sa valeur actuelle
# tant qu'une rotation volontaire n'a pas été préparée.

# Nommage des ressources.
project_name = "moustapha"
env          = "dev"

# IPv4 publique du poste utilisée lors du test SSH.
# Actualiser cette valeur si l'adresse de sortie Internet change.
allowed_ssh_cidr = ["193.52.24.26/32"]
