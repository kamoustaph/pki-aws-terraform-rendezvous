# Module RDS

## Fonction

Ce module Terraform décrit une instance Amazon RDS MySQL destinée
à l'application de gestion de rendez-vous.

Il crée :

- un groupe de sous-réseaux RDS ;
- une instance MySQL ;
- un stockage chiffré.

Il réutilise les sous-réseaux privés du module VPC et le groupe RDS
du module Security.

Il ne crée pas les tables métier, les migrations de l'application
ni le compte MySQL applicatif.

## État

Le code initial a été examiné et une version corrigée et commentée
a été proposée.

Son application locale, sa validation et son déploiement restent
à confirmer.

## Fichiers

| Fichier | Rôle |
|---|---|
| `variables.tf` | Paramètres d'entrée |
| `main.tf` | Groupe de sous-réseaux et instance RDS |
| `outputs.tf` | Informations de connexion et identifiant |
| `README.md` | Documentation du module |

## Entrées

| Variable | Type | Défaut | Description |
|---|---|---|---|
| `env` | `string` | `"dev"` | Environnement |
| `project_name` | `string` | `"moustapha"` | Nom du projet |
| `security_group_id` | `string` | Obligatoire | Groupe de sécurité RDS |
| `subnet_ids` | `list(string)` | Obligatoire | Sous-réseaux privés |
| `db_name` | `string` | `"moustaphadb"` | Base MySQL initiale |
| `db_username` | `string` | `"admin"` | Compte administrateur initial |
| `db_password` | `string` sensible | Obligatoire | Mot de passe administrateur |

La variable `vpc_id` n'est pas nécessaire : le VPC est déterminé
par les sous-réseaux fournis.

## Prérequis réseau

- Les sous-réseaux doivent appartenir au même VPC.
- Ils doivent couvrir au moins deux zones de disponibilité.
- Le groupe de sécurité doit appartenir à ce même VPC.
- Le groupe RDS doit autoriser TCP 3306 depuis le groupe applicatif.
- Les clients doivent disposer d'un chemin réseau vers la base.

La validation du nombre de sous-réseaux ne vérifie pas leur VPC
ni leurs zones de disponibilité.

## Configuration proposée

| Paramètre | Valeur |
|---|---|
| Moteur | MySQL |
| Famille de version | `8.0`, à vérifier avant déploiement |
| Classe | `db.t3.micro`, à vérifier dans la région |
| Stockage initial | 20 Gio |
| Type de stockage | `gp3` |
| Chiffrement du stockage | Activé |
| Accès public | Désactivé |
| Multi-AZ | Désactivé |
| Sauvegardes automatisées | Désactivées |
| Protection contre la suppression | Désactivée |
| Snapshot final | Désactivé |

Cette configuration vise un laboratoire temporaire.

Le chiffrement du stockage ne configure pas à lui seul TLS
pour les connexions MySQL.

## Exemple d'appel

Depuis la configuration racine :

```hcl
variable "db_password" {
  type        = string
  description = "Mot de passe administrateur RDS."
  sensitive   = true
}

module "rds" {
  source = "./modules/rds"

  project_name = "rendezvous-pki"
  env          = "dev"

  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.security.rds_sg_id

  db_name     = "rendezvousdb"
  db_username = "admin"
  db_password = var.db_password
}
```

Le fournisseur AWS doit être déclaré et configuré dans la racine.

Ne pas écrire le mot de passe dans ce bloc ni le publier dans Git.

## Sorties

| Sortie | Description |
|---|---|
| `rds_endpoint` | Nom DNS et port au format `adresse:port` |
| `rds_instance_id` | Identifiant de l'instance |
| `rds_address` | Nom DNS sans port |
| `rds_port` | Port MySQL |

Références depuis la configuration racine :

```hcl
module.rds.rds_endpoint
module.rds.rds_instance_id
module.rds.rds_address
module.rds.rds_port
```

## Secrets et comptes MySQL

Le mot de passe ne possède aucune valeur par défaut.

L'attribut `sensitive` masque son affichage habituel, mais la méthode
utilisant `password` enregistre le secret dans l'état Terraform.

Protéger les états et plans enregistrés et ne pas les publier dans Git.

Créer ensuite un compte applicatif distinct, avec des permissions
limitées aux besoins de l'application.

## Vérifications

Depuis la racine du dépôt :

```powershell
terraform fmt -recursive
terraform fmt -check -recursive
```

Après déclaration des exigences de fournisseur :

```powershell
terraform -chdir=modules/rds init -backend=false
terraform -chdir=modules/rds validate
```

Ces commandes ne créent aucune instance.

Vérifier ensuite les versions MySQL, la classe d'instance, les permissions
AWS et les coûts avant d'examiner le plan depuis la configuration racine.

Une validation syntaxique réussie ne garantit pas le déploiement.

## Limites du laboratoire

- Aucune instance de secours Multi-AZ.
- Aucune sauvegarde automatisée.
- Aucun snapshot final lors de la suppression.
- Aucune protection contre la suppression.
- Aucun compte applicatif dédié créé par ce module.
- Aucun schéma métier ou migration exécuté.
- Aucune configuration TLS cliente ou intégration PKI EJBCA.
- La disponibilité et le support du moteur restent à vérifier.

Avant un usage avec des données réelles, définir une politique
de sauvegarde, de restauration, de disponibilité et de gestion des secrets.

## Coûts

RDS entraîne des frais liés notamment à l'instance, au stockage
et aux transferts éventuels.

Une ancienne version du moteur peut également entraîner des frais
de support étendu selon son cycle de support.

Ne pas considérer cette configuration comme gratuite.

## Références

- [Terraform AWS DB Instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)
- [RDS dans un VPC](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)
- [Versions RDS MySQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/MySQL.Concepts.VersionMgmt.html)