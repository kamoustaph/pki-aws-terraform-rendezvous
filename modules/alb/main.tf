# ---------------------------------------------------------
# 1. Application Load Balancer
# ---------------------------------------------------------

resource "aws_lb" "main" {
  # Nom affiché dans AWS.
  # Attention à la limite AWS de 32 caractères pour ce nom.
  name = "alb-${var.project_name}-${var.env}"

  # false : ALB accessible depuis Internet.
  # Cela nécessite des sous-réseaux publics correctement routés.
  internal = false

  # Load balancer applicatif, adapté au trafic HTTP/HTTPS.
  load_balancer_type = "application"

  # Un sous-réseau public par zone sélectionnée.
  subnets = var.subnet_ids

  # Groupe de sécurité de l'ALB.
  # Cet argument attend une liste, même avec un seul groupe.
  security_groups = [var.security_group_id]

  tags = {
    Name = "alb-${var.project_name}-${var.env}"
  }
}


# ---------------------------------------------------------
# 2. Groupe cible
# ---------------------------------------------------------

# Le groupe cible décrit où et comment transmettre les requêtes.
resource "aws_lb_target_group" "main" {
  name = "tg-${var.project_name}-${var.env}"

  # Trafic transmis aux instances sur HTTP, port 80.
  port     = 80
  protocol = "HTTP"

  # Les cibles sont identifiées par leurs identifiants EC2.
  # C'est également le type par défaut ; il est explicité ici.
  target_type = "instance"

  vpc_id = var.vpc_id

  # Vérifications périodiques du service sur les instances.
  health_check {
    # Vérifie la page racine du serveur.
    # Elle doit répondre sans authentification avec un code accepté.
    path = "/"

    # Utilise le port sur lequel la cible reçoit le trafic : ici 80.
    port = "traffic-port"

    # Effectue une vérification toutes les 30 secondes environ.
    interval = 30

    # Attend au maximum 5 secondes pour cette vérification.
    timeout = 5

    # Nombre de succès consécutifs pour rétablir une cible
    # précédemment considérée comme défaillante.
    healthy_threshold = 2

    # Nombre d'échecs consécutifs avant de déclarer la cible défaillante.
    unhealthy_threshold = 2

    # Codes HTTP considérés comme valides.
    # Une redirection 301/302 ou une réponse 401 n'est pas acceptée.
    matcher = "200-299"
  }

  # Délai de drainage lors du retrait d'une cible.
  # L'ALB laisse les requêtes en cours se terminer,
  # dans la limite de ce délai de 300 secondes.
  deregistration_delay = 300

  tags = {
    Name = "tg-${var.project_name}-${var.env}"
  }
}


# ---------------------------------------------------------
# 3. Enregistrement des instances dans le groupe cible
# ---------------------------------------------------------

resource "aws_lb_target_group_attachment" "instances" {
  # Crée un enregistrement par identifiant fourni.
  # Une liste vide crée zéro enregistrement.
  count = length(var.instance_ids)

  # Groupe cible dans lequel enregistrer l'instance.
  target_group_arn = aws_lb_target_group.main.arn

  # Instance correspondant à l'index courant.
  target_id = var.instance_ids[count.index]

  # Port utilisé pour cette instance.
  port = 80
}


# ---------------------------------------------------------
# 4. Listener HTTP
# ---------------------------------------------------------

# Le listener reçoit les connexions des visiteurs.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn

  # Entrée HTTP uniquement.
  port     = 80
  protocol = "HTTP"

  # Toutes les requêtes qui arrivent sur ce listener sont
  # transmises au groupe cible.
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = {
    Name = "listener-http-${var.project_name}-${var.env}"
  }
}