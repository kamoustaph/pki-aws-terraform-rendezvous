# Adresse de connexion complète : nom DNS et port.
# Exemple de forme : nom-instance.xxxxx.eu-west-3.rds.amazonaws.com:3306
output "rds_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "Endpoint MySQL au format adresse:port."
}


# Identifiant AWS de l'instance RDS.
output "rds_instance_id" {
  value       = aws_db_instance.main.id
  description = "Identifiant de l'instance RDS."
}


# Nom DNS seul, utile pour construire une configuration applicative.
output "rds_address" {
  value       = aws_db_instance.main.address
  description = "Nom DNS de l'instance RDS, sans le port."
}


# Port du service MySQL.
output "rds_port" {
  value       = aws_db_instance.main.port
  description = "Port de connexion MySQL."
}