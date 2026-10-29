project_name  = "moustapha"
region        = "eu-west-3"
aws_ami       = "ami-001b955040bc46321"
instance_type = "t3.micro"
key_name      = "terraformcloud"

db_name     = "Stagingmoustaphastaging"
db_username = "Stagingadmin"
db_password = "Stagingadmin123"
env          = "staging"
allowed_ssh_cidr = []