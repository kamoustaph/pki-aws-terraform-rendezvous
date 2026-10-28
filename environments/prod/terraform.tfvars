project_name  = "moustapha"
region        = "eu-west-3"
aws_ami       = "ami-001b955040bc46321"
instance_type = "t3.medium"
key_name      = "terraformcloud"

db_name     = "Prodmoustaphaprod"
db_username = "Prodadmin"
# db_password = "Prodadmin123"
env          = "prod"
allowed_ssh_cidr = []