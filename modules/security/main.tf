# ---------------------------------------------------------
# 1. Groupes de sécurité
# ---------------------------------------------------------
#
# Un groupe de sécurité est un pare-feu associé à une ressource AWS.
# Le créer ne suffit pas : il faudra l'associer aux instances,
# au load balancer ou à la base de données.
#
# Les règles sont déclarées séparément plus bas.


# Groupe destiné aux instances qui hébergent le service Web.
resource "aws_security_group" "web" {
  name        = "web-sg-${var.project_name}-${var.env}"
  description = "Security group pour les instances web"
  vpc_id      = var.vpc_id

  tags = {
    Name = "web-sg-${var.project_name}-${var.env}"
  }
}


# Groupe destiné à une future base RDS.
# Ce module ne crée pas la base elle-même.
resource "aws_security_group" "rds" {
  name        = "rds-sg-${var.project_name}-${var.env}"
  description = "Security group pour la base RDS"
  vpc_id      = var.vpc_id

  tags = {
    Name = "rds-sg-${var.project_name}-${var.env}"
  }
}


# Groupe destiné à un futur Application Load Balancer.
# Ce module ne crée pas le load balancer lui-même.
resource "aws_security_group" "alb" {
  name        = "alb-sg-${var.project_name}-${var.env}"
  description = "Security group pour l ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "alb-sg-${var.project_name}-${var.env}"
  }
}


# ---------------------------------------------------------
# 2. Entrées vers l'ALB
# ---------------------------------------------------------

# Autorise les visiteurs IPv4 à joindre l'ALB en HTTP.
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP public vers ALB"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}


# Autorise les visiteurs IPv4 à joindre l'ALB en HTTPS.
#
# Cette règle ouvre un port ; elle ne configure pas TLS.
# Il faudra un listener HTTPS et un certificat sur le futur ALB.
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS public vers ALB"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}


# ---------------------------------------------------------
# 3. Communication ALB -> Web
# ---------------------------------------------------------

# Autorise l'ALB à initier des connexions vers les ressources
# associées au groupe Web, uniquement sur le port TCP 80.
#
# Le port du service cible et celui du health check devront être
# configurés sur 80, ou les règles devront être adaptées.
resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP sortant de ALB vers web"

  referenced_security_group_id = aws_security_group.web.id

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}


# Côté Web, accepte les connexions TCP 80 provenant des ressources
# associées au groupe ALB.
#
# On référence le groupe source plutôt qu'une adresse IP fixe.
# Aucun accès HTTP direct depuis tout Internet n'est déclaré ici.
resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP entrant depuis ALB"

  referenced_security_group_id = aws_security_group.alb.id

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}


# ---------------------------------------------------------
# 4. Administration SSH des serveurs Web
# ---------------------------------------------------------

# Crée une règle SSH par CIDR autorisé.
#
# toset transforme la liste en ensemble et élimine les doublons.
# each.value correspond au CIDR de la règle en cours.
#
# Avec la valeur par défaut [], aucune règle SSH n'est créée.
resource "aws_vpc_security_group_ingress_rule" "web_ssh" {
  for_each = toset(var.allowed_ssh_cidr)

  security_group_id = aws_security_group.web.id
  description       = "SSH depuis une plage autorisee"

  cidr_ipv4   = each.value
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}


# ---------------------------------------------------------
# 5. Sorties des serveurs Web
# ---------------------------------------------------------

# Conserve le comportement de ton code initial :
# les serveurs Web peuvent initier tout trafic IPv4 sortant.
#
# Cela couvre notamment les mises à jour, téléchargements
# d'images Docker et connexions vers la base.
#
# Les routes et les règles des destinations doivent aussi
# permettre ces communications.
resource "aws_vpc_security_group_egress_rule" "web_outbound" {
  security_group_id = aws_security_group.web.id
  description       = "Tout trafic IPv4 sortant depuis web"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  # Avec "-1", tous les protocoles sont autorisés.
  # from_port et to_port ne sont donc pas renseignés.
}


# ---------------------------------------------------------
# 6. Communication Web -> RDS
# ---------------------------------------------------------

# Autorise MySQL sur le port 3306 uniquement depuis les ressources
# associées au groupe Web.
#
# Une ressource externe ne reçoit pas cette autorisation
# simplement parce qu'elle connaît l'adresse de la base.
#
# Si la base utilise PostgreSQL, le port devra être adapté.
resource "aws_vpc_security_group_ingress_rule" "rds_from_web" {
  security_group_id = aws_security_group.rds.id
  description       = "MySQL entrant depuis web"

  referenced_security_group_id = aws_security_group.web.id

  ip_protocol = "tcp"
  from_port   = 3306
  to_port     = 3306
}


# Conserve la sortie IPv4 générale de ton groupe RDS initial.
# Elle pourra être restreinte selon les besoins de la future base.
resource "aws_vpc_security_group_egress_rule" "rds_outbound" {
  security_group_id = aws_security_group.rds.id
  description       = "Tout trafic IPv4 sortant depuis RDS"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}