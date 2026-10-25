# IPv4 publique attribuée à l'instance, si elle en possède une.
# Cette adresse n'est pas une Elastic IP et peut changer
# après un arrêt suivi d'un redémarrage.
output "ec2_public_ip" {
  value       = aws_instance.vm_instance.public_ip
  description = "Adresse IPv4 publique de l'instance, si disponible."
}


# Nom DNS public, s'il est disponible.
output "public_dns" {
  value       = aws_instance.vm_instance.public_dns
  description = "Nom DNS public de l'instance."
}


# Identifiant AWS de l'instance.
output "instance_id" {
  value       = aws_instance.vm_instance.id
  description = "Identifiant de l'instance EC2."
}


# Adresse privée utile pour les échanges internes,
# ou pour SSH depuis un réseau ayant accès au VPC.
output "ec2_private_ip" {
  value       = aws_instance.vm_instance.private_ip
  description = "Adresse IPv4 privee de l'instance."
}


# Commande indicative pour un accès SSH direct par IPv4 publique.
#
# Les guillemets protègent les chemins contenant des espaces.
# La présence d'une commande ne garantit pas l'accès :
# réseau, règles SSH, clé et utilisateur doivent être corrects.
#
# Sans IPv4 publique, retourne null.
output "ssh_command" {
  value = (
    aws_instance.vm_instance.public_ip != null &&
    aws_instance.vm_instance.public_ip != ""
    ? "ssh -i \"${var.private_key_path}\" ${var.ssh_user}@${aws_instance.vm_instance.public_ip}"
    : null
  )

  description = "Commande SSH publique indicative ; null sans IPv4 publique."
}