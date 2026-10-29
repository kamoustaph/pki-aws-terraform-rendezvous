project_name  = "moustapha"
region        = "eu-west-3"
aws_ami       = "ami-001b955040bc46321"
instance_type = "t3.micro"
key_name      = "terraformcloud"

db_name     = "Devmoustaphadev"
db_username = "Devadmin"
db_password = "Devadmin123"
env         = "dev"
# Vérifier que ton IPv4 publique n'a pas changé.
allowed_ssh_cidr = ["193.52.24.26/32"]