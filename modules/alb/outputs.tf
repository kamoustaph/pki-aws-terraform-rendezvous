# Nom DNS attribué par AWS au load balancer.
#
# Ce nom pointe vers l'ALB et non directement vers une instance.
output "alb_dns" {
  value       = aws_lb.main.dns_name
  description = "Nom DNS de l'Application Load Balancer."
}


# URL de l'application : https:// si un certificat est fourni, sinon http://.
#
# La présence de cette URL ne garantit pas que l'application
# soit déjà installée ou que les cibles soient opérationnelles.
output "url_alb" {
  value       = "${local.https_actif ? "https" : "http"}://${aws_lb.main.dns_name}"
  description = "URL de l'application via l'ALB (https si certificat_arn est fourni)."
}


# Identifiant de la zone hébergée AWS propre au load balancer.
#
# Il sert notamment comme zone_id de la cible d'un enregistrement
# Alias Route 53.
#
# Ce n'est pas l'identifiant de ta propre zone DNS de domaine.
output "zone_id" {
  value       = aws_lb.main.zone_id
  description = "Identifiant de la zone AWS de l'ALB pour un Alias Route 53."
}


# ARN du load balancer, utile pour d'autres ressources AWS.
output "alb_arn" {
  value       = aws_lb.main.arn
  description = "ARN de l'Application Load Balancer."
}


# ARN du groupe cible, utile pour vérifier la santé des instances.
output "target_group_arn" {
  value       = aws_lb_target_group.main.arn
  description = "ARN du groupe cible des instances EC2."
}


# Indique si le listener HTTPS est actif.
output "https_enabled" {
  value       = local.https_actif
  description = "true si le listener HTTPS 443 est cree."
}
