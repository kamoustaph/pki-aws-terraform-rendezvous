# Crée une instance EC2 à partir de l'AMI fournie.
resource "aws_instance" "vm_instance" {
  # Image du système d'exploitation.
  ami = var.ami

  # Capacité de calcul et mémoire.
  instance_type = var.instance_type

  # Placement réseau de l'instance.
  subnet_id = var.subnet_id

  # Groupes de sécurité identifiés par leurs IDs.
  # Pour une instance dans un VPC, utiliser cet argument
  # plutôt que security_groups.
  vpc_security_group_ids = var.security_group_ids

  # Paire de clés existante dans AWS.
  # AWS place la clé publique sur l'instance au premier démarrage.
  # La clé privée reste sur ton poste.
  key_name = var.key_name

  # Aucun réglage d'adresse publique n'est imposé ici.
  # L'attribution dépend donc du sous-réseau utilisé.
  #
  # Dans ton module VPC actuel :
  # - les sous-réseaux publics activent l'attribution automatique ;
  # - les sous-réseaux privés ne l'activent pas.

  user_data = var.user_data != "" ? var.user_data : null

  # Le user data n'est exécuté qu'au premier démarrage.
  # Si le script change, l'instance est recréée pour qu'il s'applique.
  user_data_replace_on_change = true

  # Profil IAM de l'instance (rôle lu par les commandes AWS exécutées sur la machine).
  # null : aucun rôle, comportement d'origine du module.
  iam_instance_profile = var.iam_instance_profile

  # Exige IMDSv2 (jeton de session) pour lire les identifiants du rôle :
  # protège contre le vol d'identifiants par requête falsifiée (SSRF).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Disque système : place pour Docker et les images de l'application.
  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name        = var.instance_name != null ? var.instance_name : "ec2-${var.project_name}-${var.env}"
    Environment = var.env
    Project     = var.project_name
  }
}
