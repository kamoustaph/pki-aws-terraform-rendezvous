# Module VPC

## Fonction

Décrire le réseau AWS du laboratoire PKI et de l'application de gestion de rendez-vous. Ce document correspond au code initial fourni ; les corrections ci-dessous doivent encore être appliquées et validées.

## Ressources

| Ressource | Quantité |
|---|---|
| VPC avec DNS activé | 1 |
| Sous-réseaux publics | Longueur de `public_subnet_cidr` |
| Sous-réseaux privés | Longueur de `private_subnet_cidr` |
| Internet Gateway | 1 |
| Elastic IP et NAT Gateway | 1 de chaque |
| Tables de routage | 1 publique et 1 privée |
| Associations aux tables | 1 par sous-réseau |

Les sous-réseaux publics ont une route par défaut vers l'Internet Gateway. Les sous-réseaux privés doivent avoir une route par défaut vers la NAT Gateway. Une route ne remplace pas les règles de sécurité nécessaires aux communications.

## Entrées

| Variable | Type | Valeur initiale |
|---|---|---|
| `env` | `string` | `dev` |
| `project_name` | `string` | `moustapha` |
| `vpc_cidr` | `string` | `10.0.0.0/16` |
| `public_subnet_cidr` | `list(string)` | `10.0.1.0/24`, `10.0.2.0/24` |
| `private_subnet_cidr` | `list(string)` | `10.0.3.0/24`, `10.0.4.0/24` |
| `availability_zones` | `list(string)` | `us-east-3a`, `us-east-3b` : valeurs invalides à corriger |

## Sorties

| Sortie | Description |
|---|---|
| `vpc_id` | Identifiant du VPC |
| `public_subnet_ids` | Identifiants des sous-réseaux publics |
| `private_subnet_ids` | Identifiants des sous-réseaux privés |

## Exemple d'appel futur

Depuis un `main.tf` à la racine du dépôt, avec le fournisseur AWS configuré sur `eu-west-3` :

```hcl
module "vpc" {
  source = "./modules/vpc"

  project_name        = "rendezvous-pki"
  env                 = "dev"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidr = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones  = ["eu-west-3a", "eu-west-3b"]
}
```

Vérifier les zones disponibles dans le compte avant utilisation. Ce bloc est un exemple d'appel, pas une configuration racine complète.

