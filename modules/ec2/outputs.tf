# IPv4 publique, si l'instance en possède une.
# Cette adresse peut changer après un arrêt suivi d'un démarrage.
output "ec2_public_ip" {
  value       = aws_instance.vm_instance.public_ip
  description = "Adresse IPv4 publique de l'instance, si disponible."
}


# Nom DNS public, s'il est disponible.
output "public_dns" {
  value       = aws_instance.vm_instance.public_dns
  description = "Nom DNS public de l'instance."
}


# Identifiant attribué par AWS à l'instance.
output "instance_id" {
  value       = aws_instance.vm_instance.id
  description = "Identifiant de l'instance EC2."
}


# IPv4 privée utilisée pour les communications internes.
output "ec2_private_ip" {
  value       = aws_instance.vm_instance.private_ip
  description = "Adresse IPv4 privée de l'instance."
}


# Nom DNS privé de l'instance.
# Cette sortie est nécessaire pour les références
# module.ec2-1.private_dns et module.ec2-2.private_dns.
output "private_dns" {
  value       = aws_instance.vm_instance.private_dns
  description = "Nom DNS privé de l'instance EC2."
}


# Commande indicative pour une connexion SSH par IPv4 publique.
# Le chemin de la clé est placé entre guillemets.
#
# Aucun fichier privé n'est lu par cette sortie.
# Sans IPv4 publique, la valeur retournée est null.
output "ssh_command" {
  value = (
    aws_instance.vm_instance.public_ip != null &&
    aws_instance.vm_instance.public_ip != ""
    ? "ssh -i \"${var.private_key_path}\" ${var.ssh_user}@${aws_instance.vm_instance.public_ip}"
    : null
  )

  description = "Commande SSH publique indicative ; null sans IPv4 publique."
}