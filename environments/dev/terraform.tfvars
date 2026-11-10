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
# Certificat EJBCA (Lab-IntermediateCA-SoftHSM2) importe dans ACM - HTTPS sur l'ALB
certificate_arn = "arn:aws:acm:eu-west-3:231644789895:certificate/5c6f0b7d-92c0-4568-87f5-8c4fb01fa4ce"
