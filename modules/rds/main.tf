# ---------------------------------------------------------
# 1. Groupe de sous-réseaux RDS
# ---------------------------------------------------------

# Indique à RDS les sous-réseaux utilisables pour placer la base.
# Ce groupe ne crée pas de nouveaux sous-réseaux.
resource "aws_db_subnet_group" "main" {
  # Exemple : db-subnet-group-moustapha-dev
  name = "db-subnet-group-${var.project_name}-${var.env}"

  # Identifiants des sous-réseaux privés fournis par le module appelant.
  subnet_ids = var.subnet_ids

  tags = {
    Name = "db-subnet-group-${var.project_name}-${var.env}"
  }
}


# ---------------------------------------------------------
# 2. Instance RDS MySQL
# ---------------------------------------------------------

resource "aws_db_instance" "main" {
  # Nom AWS de l'instance, différent du nom de la base MySQL.
  # Utiliser des noms de projet et d'environnement compatibles
  # avec les contraintes de nommage RDS.
  identifier = "rds-${var.project_name}-${var.env}"

  # Capacité initiale du stockage en Gio.
  allocated_storage = 20

  # Type de stockage SSD à usage général.
  storage_type = "gp3"

  # Active le chiffrement du stockage avec une clé KMS AWS par défaut.
  # Cela ne configure pas le chiffrement TLS des connexions clientes.
  storage_encrypted = true

  # Moteur et famille de version conservés depuis ton code initial.
  # Vérifier la version réellement disponible et son support
  # dans la région avant le déploiement.
  engine         = "mysql"
  engine_version = "8.0"

  # Taille de l'instance.
  # Sa disponibilité doit être vérifiée pour le moteur et la région.
  instance_class = "db.t3.micro"

  # Nom de la base initiale et compte administrateur.
  # Ces paramètres ne sont pas des identifiants de VPC.
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Groupe de paramètres correspondant à MySQL 8.0.
  # À adapter si la version majeure du moteur change.
  parameter_group_name = "default.mysql8.0"

  # Place l'instance dans le groupe de sous-réseaux défini plus haut.
  # Cette référence crée une dépendance implicite.
  db_subnet_group_name = aws_db_subnet_group.main.name

  # Associe le groupe de sécurité RDS.
  # L'argument attend une liste, même avec un seul groupe.
  vpc_security_group_ids = [var.security_group_id]

  # N'attribue pas d'accès public à l'instance.
  # Les clients doivent disposer d'un chemin réseau privé
  # et être autorisés par les règles de sécurité.
  publicly_accessible = false

  # -------------------------------------------------------
  # Paramètres conservés pour un laboratoire temporaire
  # -------------------------------------------------------

  # Une seule instance, sans instance de secours Multi-AZ.
  # Deux zones restent nécessaires dans le groupe de sous-réseaux.
  multi_az = false

  # Désactive les sauvegardes automatisées.
  # Pas de restauration à un instant donné avec cette configuration.
  backup_retention_period = 0

  # Autorise la suppression de l'instance.
  deletion_protection = false

  # Ne crée pas de snapshot final à la suppression.
  # Avec les sauvegardes désactivées, ne compter sur aucune
  # restauration automatique des données après destruction.
  skip_final_snapshot = true

  tags = {
    Name        = "rds-${var.project_name}-${var.env}"
    Project     = var.project_name
    Environment = var.env
  }
}