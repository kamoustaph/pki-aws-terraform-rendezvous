output "s3_bucket_name" {
  description = "Nom du bucket utilisé pour les states Terraform."
  value       = aws_s3_bucket.terraform_bucket.bucket
}