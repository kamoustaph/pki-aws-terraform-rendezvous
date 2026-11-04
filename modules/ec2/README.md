# Module EC2

## Fonction

Ce module Terraform crée une instance EC2 à partir d'une AMI fournie.

Il réutilise :

- un sous-réseau du module VPC ;
- les groupes de sécurité du module Security ;
- une paire de clés SSH déjà enregistrée dans AWS.

Il ne crée pas la paire de clés et n'installe pas les logiciels applicatifs.

## État

Le code initial a été examiné et une version corrigée et commentée
a été proposée.

L'application des corrections, la validation Terraform, le déploiement
et la connexion SSH restent à confirmer.

## Fichiers

| Fichier | Rôle |
|---|---|
| `variables.tf` | Paramètres de l'instance et de la commande SSH |
| `main.tf` | Instance EC2 |
| `outputs.tf` | Identifiant, adresses et commande SSH indicative |
| `README.md` | Documentation |

## Entrées

| Variable | Type | Défaut | Description |
|---|---|---|---|
| `ami` | `string` | Obligatoire | AMI disponible dans la région |
| `instance_type` | `string` | `"t2.micro"` | Type d'instance |
| `subnet_id` | `string` | Obligatoire | Sous-réseau de l'instance |
| `security_group_ids` | `list(string)` | Obligatoire | Groupes de sécurité |
| `key_name` | `string` | `"terraformcloud"` | Paire de clés existante dans AWS |
| `ssh_user` | `string` | `"ubuntu"` | Utilisateur du système |
| `private_key_path` | `string` | `"./key/terraformcloud.pem"` | Chemin local de la clé privée |
| `env` | `string` | `"dev"` | Environnement |
| `project_name` | `string` | `"moustapha"` | Nom du projet |

L'AMI doit être compatible avec le type d'instance et exister dans
la région configurée par le fournisseur AWS.

Les groupes de sécurité doivent appartenir au même VPC que le sous-réseau.

## Groupes de sécurité

Le module utilise :

```hcl
vpc_security_group_ids = var.security_group_ids
```

Cet argument permet d'associer des groupes par leurs identifiants
à une instance dans un VPC.

Le module ne crée ni ne modifie les règles de ces groupes.

## Paire de clés SSH

Deux éléments sont nécessaires :

- une clé publique enregistrée dans AWS sous le nom `key_name` ;
- la clé privée correspondante conservée sur le poste local.

La paire AWS doit exister dans la région de l'instance avant sa création.

`key_name` n'est pas un chemin de fichier.

`private_key_path` sert uniquement à construire une commande SSH :
Terraform ne lit pas et ne transmet pas le fichier privé.

Le nom du fichier privé peut être différent du nom de la paire AWS,
à condition qu'il contienne la clé correspondante.

Le dossier local `key/` doit être exclu de Git.

## Accès réseau SSH

Pour un accès direct depuis le poste local, il faut :

- une instance avec une adresse publique ;
- un sous-réseau associé à une route vers l'Internet Gateway ;
- une règle TCP 22 autorisant l'adresse publique du poste ;
- des ACL réseau compatibles ;
- un service SSH actif ;
- la bonne clé privée et le bon utilisateur.

Le module Security désactive SSH par défaut avec une liste vide.
Configurer `allowed_ssh_cidr` si cet accès est nécessaire.

Une instance privée nécessite un chemin d'administration privé,
un bastion ou une solution comme Session Manager correctement configurée.

Une NAT Gateway ne fournit pas d'accès SSH entrant depuis Internet.

## Exemple d'appel

Depuis la configuration racine :

```hcl
variable "ec2_ami" {
  type        = string
  description = "AMI Ubuntu compatible dans la region cible."
}

module "ec2" {
  source = "./modules/ec2"

  project_name = "rendezvous-pki"
  env          = "dev"

  ami           = var.ec2_ami
  instance_type = "t2.micro"

  subnet_id          = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.security.aws_sg_id]

  key_name         = "terraformcloud"
  private_key_path = "./key/terraformcloud.pem"
  ssh_user         = "ubuntu"
}
```

Cet exemple suppose les modules VPC et Security déjà déclarés.
Il vise un premier laboratoire avec accès public pour l'administration.

La configuration du fournisseur AWS et la valeur réelle de l'AMI
restent à fournir.



## Options ajoutées pour l'application Yoon

Ces variables sont toutes optionnelles : un appel existant du module reste valide sans changement.

| Variable | Type | Défaut | Description |
|---|---|---|---|
| `iam_instance_profile` | string | `null` | Profil IAM attaché à l'instance (fourni par le module [`app`](../app/README.md)) |
| `root_volume_size` | number | `16` | Taille du disque système en Go (gp3, chiffré) |
| `instance_name` | string | `null` | Tag `Name` ; `null` conserve `ec2-<projet>-<env>` |

Comportements ajoutés dans `main.tf` :

- `user_data_replace_on_change = true` : si le script de démarrage change, l'instance est recréée
  (le user data n'est exécuté qu'au premier démarrage).
- `metadata_options` : IMDSv2 obligatoire, ce qui protège les identifiants du rôle IAM contre les requêtes falsifiées.
- `root_block_device` : disque gp3 chiffré, de taille `root_volume_size`.


## Sorties

| Sortie | Description |
|---|---|
| `ec2_public_ip` | IPv4 publique, si disponible |
| `public_dns` | Nom DNS public, si disponible |
| `instance_id` | Identifiant EC2 |
| `ec2_private_ip` | IPv4 privée |
| `ssh_command` | Commande publique indicative, ou `null` |

La commande SSH doit être exécutée depuis un dossier où le chemin
de la clé privée est valide.

Les sorties du module enfant doivent être relayées par des outputs
du module racine pour être consultées directement avec `terraform output`.

## Utilisateur SSH

Le compte dépend de l'AMI :

| Système | Utilisateur habituel |
|---|---|
| Ubuntu | `ubuntu` |
| Amazon Linux | `ec2-user` |

Vérifier les instructions de l'éditeur pour les autres AMI.

## Vérifications

Depuis la racine :

```powershell
terraform fmt -recursive
terraform fmt -check -recursive
```

Après déclaration des exigences de fournisseur :

```powershell
terraform -chdir=modules/ec2 init -backend=false
terraform -chdir=modules/ec2 validate
```

Vérifier la paire de clés :

```powershell
aws ec2 describe-key-pairs --key-names terraformcloud --region eu-west-3 --profile terraform
```

Ces commandes ne créent pas d'instance.

Après préparation de la configuration racine, examiner le plan avant
déploiement, puis vérifier réellement la connexion SSH.

## Limites

- Aucune installation de Docker ou de l'application.
- Aucun rôle IAM associé par ce module.
- Aucune adresse Elastic IP réservée.
- Aucune automatisation de configuration Ansible.
- Aucun certificat ou mTLS installé.
- Aucune création ni rotation de la paire de clés.
- Aucune vérification automatique de la correspondance entre clé privée
  et paire AWS.
- Le type `t2.micro` n'est pas une garantie de gratuité.

## Coûts et secrets

L'instance, ses volumes et une éventuelle IPv4 publique peuvent
entraîner des frais.

Ne jamais publier la clé privée dans Git, dans un plan Terraform
ou dans le contenu d'une variable Terraform.

## Références

- [Instance EC2 avec Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance)
- [Paires de clés EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)