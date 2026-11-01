# Affiche le nom du bucket après la création du bootstrap.
#
# Cette sortie facilite la configuration des backends.
# Elle ne configure pas automatiquement les environnements.
output "s3_bucket_name" {
  description = "Nom du bucket utilisé pour les states Terraform."
  value       = aws_s3_bucket.terraform_bucket.bucket
}