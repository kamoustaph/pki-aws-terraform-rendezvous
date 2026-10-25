# Module VPC

## Fonction

Ce module Terraform décrit le réseau AWS du laboratoire PKI et de l'application de gestion de rendez-vous.

Il crée un VPC, des sous-réseaux publics et privés, ainsi que les passerelles et tables de routage nécessaires.

Le code est commenté, les zones par défaut correspondent à Paris et la route privée utilise `nat_gateway_id`.

La validation Terraform et le déploiement restent à effectuer.

## Ressources

| Ressource | Quantité | Rôle |
|---|---|---|
| VPC avec DNS activé | 1 | Réseau principal |
| Sous-réseaux publics | Longueur de `public_subnet_cidr` | Hébergement des ressources nécessitant un routage direct vers Internet |
| Sous-réseaux privés | Longueur de `private_subnet_cidr` | Hébergement des ressources sans routage direct vers Internet |
| Internet Gateway | 1 | Liaison du VPC avec Internet |
| Elastic IP | 1 | Adresse IPv4 publique de la NAT Gateway |
| NAT Gateway | 1 | Connexions IPv4 sortantes des ressources privées |
| Table de routage publique | 1 | Route par défaut vers l'Internet Gateway |
| Table de routage privée | 1 | Route par défaut vers la NAT Gateway |
| Associations aux tables | 1 par sous-réseau | Attribution de la table appropriée à chaque sous-réseau |

Ce module ne crée aucune instance EC2, aucun groupe de sécurité ni composant applicatif ou PKI.

## Fichiers

| Fichier | Contenu |
|---|---|
| `main.tf` | Déclaration des ressources réseau |
| `variables.tf` | Paramètres d'entrée du module |
| `outputs.tf` | Valeurs de sortie du module |
| `README.md` | Documentation du module |

## Entrées

Toutes les variables possèdent une valeur par défaut et peuvent être remplacées lors de l'appel du module.

| Variable | Type | Valeur par défaut | Description |
|---|---|---|---|
| `env` | `string` | `"dev"` | Nom de l'environnement utilisé dans les tags |
| `project_name` | `string` | `"moustapha"` | Nom du projet utilisé dans les tags |
| `vpc_cidr` | `string` | `"10.0.0.0/16"` | Plage IPv4 du VPC |
| `public_subnet_cidr` | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` | Plages IPv4 des sous-réseaux publics |
| `private_subnet_cidr` | `list(string)` | `["10.0.3.0/24", "10.0.4.0/24"]` | Plages IPv4 des sous-réseaux privés |
| `availability_zones` | `list(string)` | `["eu-west-3a", "eu-west-3b"]` | Zones de disponibilité utilisées |

La région cible est Paris : `eu-west-3`.

La région doit être définie dans le fournisseur AWS du module racine. La variable `availability_zones` ne configure pas elle-même la région.

Les valeurs `dev`, `staging` et `prod` sont des conventions de nommage : aucun bloc de validation ne limite actuellement `env` à ces valeurs.

## Répartition des sous-réseaux

Le module utilise `count` pour créer les sous-réseaux.

Chaque plage CIDR est associée à la zone située au même index dans `availability_zones`.

Avec les valeurs par défaut :

| Index | Zone | Sous-réseau public | Sous-réseau privé |
|---|---|---|---|
| `0` | `eu-west-3a` | `10.0.1.0/24` | `10.0.3.0/24` |
| `1` | `eu-west-3b` | `10.0.2.0/24` | `10.0.4.0/24` |

La NAT Gateway est placée dans le premier sous-réseau public, à l'index `0`.

## Routage

### Sous-réseaux publics

La table publique contient une route par défaut IPv4 :

```hcl
route {
  cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.main.id
}
```

Tous les sous-réseaux publics sont associés à cette table.

L'attribution automatique d'une IPv4 publique est activée par défaut pour les instances lancées dans ces sous-réseaux. Ce réglage peut être remplacé au lancement.

Une route vers Internet ne suffit pas à autoriser les communications : les adresses IP et les règles de sécurité doivent également être adaptées.

### Sous-réseaux privés

La table privée contient une route par défaut IPv4 :

```hcl
route {
  cidr_block     = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main.id
}
```

Tous les sous-réseaux privés sont associés à cette table.

Les ressources privées peuvent ainsi initier des connexions vers Internet et recevoir les réponses, sous réserve des règles de sécurité.

La NAT Gateway ne permet pas des connexions entrantes initiées depuis Internet vers ces ressources privées.

### Communications internes

AWS ajoute automatiquement une route locale permettant le routage entre les sous-réseaux du VPC.

Les groupes de sécurité et les ACL réseau déterminent ensuite les communications autorisées.

## Sorties

| Sortie | Description |
|---|---|
| `vpc_id` | Identifiant du VPC créé |
| `public_subnet_ids` | Liste des identifiants des sous-réseaux publics |
| `private_subnet_ids` | Liste des identifiants des sous-réseaux privés |

Si le bloc d'appel est nommé `vpc`, les sorties sont accessibles avec :

```hcl
module.vpc.vpc_id
module.vpc.public_subnet_ids
module.vpc.private_subnet_ids
```

Pour sélectionner le premier sous-réseau public :

```hcl
module.vpc.public_subnet_ids[0]
```

## Exemple d'utilisation

Depuis un fichier `main.tf` à la racine du dépôt :

```hcl
module "vpc" {
  source = "./modules/vpc"

  project_name       = "rendezvous-pki"
  env                = "dev"
  vpc_cidr           = "10.0.0.0/16"

  public_subnet_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidr = ["10.0.3.0/24", "10.0.4.0/24"]

  availability_zones = ["eu-west-3a", "eu-west-3b"]
}
```

Cet exemple montre uniquement l'appel du module.

La configuration racine doit également déclarer et configurer le fournisseur AWS pour la région `eu-west-3`.

Le chemin `source` est relatif au dossier contenant le bloc `module`.

### Exposer une sortie depuis la racine

Dans le fichier `outputs.tf` du module racine :

```hcl
output "vpc_id" {
  description = "Identifiant du VPC créé par le module réseau"
  value       = module.vpc.vpc_id
}
```

Après un déploiement réussi, cette sortie peut être consultée avec :

```powershell
terraform output vpc_id
```

## Contraintes et limites

- Au moins un sous-réseau public est nécessaire, car la NAT Gateway utilise `aws_subnet.public[0]`.
- Chaque liste de sous-réseaux doit contenir au plus autant d'éléments que la liste des zones.
- Les zones doivent appartenir à la région configurée et être disponibles dans le compte.
- Les CIDR des sous-réseaux doivent être inclus dans celui du VPC.
- Les CIDR des sous-réseaux ne doivent pas se chevaucher.
- Le module utilise `count` : réordonner les listes peut changer l'association entre les adresses Terraform et les ressources AWS.
- Une seule NAT Gateway est créée, même si aucun sous-réseau privé n'est demandé.
- La NAT Gateway est partagée par tous les sous-réseaux privés et n'est pas redondante entre les zones.
- Le module configure le routage IPv4 ; aucune configuration IPv6 n'est définie.

Cette configuration convient à un laboratoire. Une architecture de production nécessite une analyse complémentaire de la disponibilité, de la sécurité et des coûts.

## Vérifications

Depuis la racine du dépôt, formater les fichiers :

```powershell
terraform fmt -recursive
```

Vérifier le formatage :

```powershell
terraform fmt -check -recursive
```

Vérifier les zones disponibles dans le compte :

```powershell
aws ec2 describe-availability-zones --region eu-west-3 --profile terraform --query "AvailabilityZones[].ZoneName" --output table
```

Après ajout des exigences de fournisseur au module, initialiser ses dépendances et valider sa configuration :

```powershell
terraform -chdir=modules/vpc init -backend=false
terraform -chdir=modules/vpc validate
```

Ces commandes ne déploient pas le réseau.

La validation ne garantit pas les permissions AWS ni la réussite d'un déploiement. Un plan devra être examiné depuis la configuration racine avant tout `apply`.

## État des travaux

- [x] Décrire les ressources du module VPC.
- [x] Commenter les fichiers Terraform.
- [x] Corriger les zones par défaut vers Paris.
- [x] Utiliser `nat_gateway_id` dans la route privée.
- [ ] Vérifier les zones disponibles dans le compte.
- [ ] Déclarer les exigences de fournisseur.
- [ ] Vérifier le formatage et valider le module.
- [ ] Ajouter la configuration racine.
- [ ] Examiner le plan et les coûts.
- [ ] Déployer et vérifier le réseau.

Aucun résultat de validation ni déploiement réussi n'est confirmé à ce stade.

## Coûts et protection des fichiers

La NAT Gateway, l'adresse IPv4 publique et certains transferts de données peuvent entraîner des frais après déploiement.

Ne pas publier les états Terraform, plans enregistrés, clés privées ou identifiants AWS.

Les fichiers Terraform décrivent l'infrastructure ; leur publication dans GitHub ne crée aucune ressource AWS.

## Références

- [Modules Terraform](https://developer.hashicorp.com/terraform/language/modules)
- [Fournisseur AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Tables de routage AWS avec Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table)