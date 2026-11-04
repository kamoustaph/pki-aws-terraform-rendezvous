output "instance_profile_name" {
  description = "Profil IAM a attacher aux instances EC2."
  value       = aws_iam_instance_profile.ec2.name
}

output "user_data" {
  description = "Scripts de demarrage : cle primary (donnees de demo possibles) et secondary."
  value       = local.user_data
}

output "ssm_prefix" {
  description = "Prefixe des parametres SSM de l'environnement."
  value       = local.prefix
}

output "ecr_registry" {
  description = "Adresse du registre ECR du compte."
  value       = local.registry
}
