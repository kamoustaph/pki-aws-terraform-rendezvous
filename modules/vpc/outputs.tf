# Les outputs sont les valeurs de sortie du module.
# Ils permettent au module appelant de récupérer les identifiants
# des ressources créées, par exemple pour y placer une instance EC2.
#
# Un output ne crée aucune ressource AWS.


# Expose l'identifiant du VPC créé dans main.tf.
output "vpc_id" {
  # aws_vpc.main : référence au VPC du module.
  # .id          : identifiant attribué par AWS, par exemple vpc-012345...
  value = aws_vpc.main.id

  # Explique la valeur retournée.
  description = "Identifiant de notre VPC"
}


# Expose la liste des identifiants des sous-réseaux publics.
output "public_subnet_ids" {
  # Les sous-réseaux sont créés avec count dans main.tf.
  #
  # [*] sélectionne tous les sous-réseaux de cette collection.
  # .id récupère l'identifiant de chacun.
  #
  # Exemple de résultat avec deux sous-réseaux :
  # ["subnet-012345...", "subnet-067890..."]
  value = aws_subnet.public[*].id

  description = "IDs des sous-réseaux publics"
}


# Expose la liste des identifiants des sous-réseaux privés.
output "private_subnet_ids" {
  # Même principe : récupère l'identifiant de chaque sous-réseau privé.
  # L'ordre correspond à celui des ressources créées avec count.
  value = aws_subnet.private[*].id

  description = "IDs des sous-réseaux privés"
}