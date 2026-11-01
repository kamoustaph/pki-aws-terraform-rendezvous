terraform {
  # Configure le stockage distant du state de cet environnement.
  # Le bucket doit exister avant l'exécution de terraform init.
  backend "s3" {
    bucket = "terraform-bucket-moustapha-2026"

    # Chemin de l'objet dans S3 pour le workspace default.
    # Chaque environnement utilise une clé différente.
    key = "dev/terraform.tfstate"

    # Région du bucket, indépendamment des ressources déployées.
    region = "eu-west-3"

    # Active le verrouillage natif S3.
    # Nécessite Terraform >= 1.10 ; compatible avec ta version 1.17.
    #
    # Terraform crée temporairement un fichier :
    # dev/terraform.tfstate.tflock
    #
    # Il évite les modifications concurrentes du même state.
    # Les identifiants utilisés doivent pouvoir créer, lire
    # et supprimer ce fichier de verrouillage.
    use_lockfile = true

    # Demande le chiffrement côté serveur des objets écrits
    # par le backend, en complément du réglage du bucket.
    encrypt = true

    # DynamoDB n'est pas nécessaire avec use_lockfile.
    # Aucune clé AWS ne doit être écrite dans ce fichier.
  }
}