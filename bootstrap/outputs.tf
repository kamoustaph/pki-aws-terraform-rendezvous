# Affiche le nom du bucket après la création du bootstrap.
#
# Cette sortie facilite la configuration des backends.
# Elle ne configure pas automatiquement les environnements.
output "s3_bucket_name" {
  description = "Nom du bucket utilisé pour les states Terraform."
  value       = aws_s3_bucket.terraform_bucket.bucket
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN du rôle à mettre dans le pipeline"
}

# ---------------------------------------------------------
# Sorties ajoutées pour le déploiement de Yoon
# ---------------------------------------------------------

output "ecr_repository_urls" {
  description = "URL des registres ECR (api et web)."
  value       = { for k, r in aws_ecr_repository.app : k => r.repository_url }
}

output "app_deploy_role_arn" {
  description = "ARN du rôle à mettre dans le secret AWS_DEPLOY_ROLE_ARN des dépôts GestionVoyageBakend et GestionVoyageFrontend."
  value       = aws_iam_role.app_deploy.arn
}
