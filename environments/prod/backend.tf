terraform {
    backend "s3" {
        bucket = "terraform-bucket-moustapha-2026"
        key = "prod/terraform.tfstate"
        region = "eu-west-3"
        # dynamodb_table = "terraform-lock-moustapha"
        use_lockfile = true
        encrypt = true

    }
}