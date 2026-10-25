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

  tags = {
    Name        = "ec2-${var.project_name}-${var.env}"
    Environment = var.env
    Project     = var.project_name
  }
}