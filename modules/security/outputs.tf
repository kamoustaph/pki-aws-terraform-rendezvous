# Expose l'identifiant du groupe des serveurs Web.
output "aws_sg_id" {
  # .id retourne uniquement l'identifiant, par exemple sg-012345...
  #
  # Sans .id, Terraform retournerait l'objet complet du groupe.
  value       = aws_security_group.web.id
  description = "Identifiant du groupe de securite des instances web"
}


# Expose l'identifiant du groupe destiné à la base RDS.
output "rds_sg_id" {
  value       = aws_security_group.rds.id
  description = "Identifiant du groupe de securite RDS"
}


# Expose l'identifiant du groupe destiné au load balancer.
output "alb_sg_id" {
  value       = aws_security_group.alb.id
  description = "Identifiant du groupe de securite ALB"
}