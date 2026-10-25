# Module ALB

## Fonction

Ce module Terraform décrit un Application Load Balancer public
qui transmet les requêtes HTTP vers des instances EC2 sur le port 80.

Il crée :

- un Application Load Balancer ;
- un groupe cible ;
- un enregistrement par instance fournie ;
- un listener HTTP sur le port 80.

Il ne crée ni les instances EC2 ni les services applicatifs.

## État

Le code initial a été examiné et une version corrigée et commentée
a été proposée.

L'application locale des corrections, la validation Terraform,
le déploiement et les tests HTTP restent à confirmer.

## Fichiers

| Fichier | Rôle |
|---|---|
| `variables.tf` | Paramètres du module |
| `main.tf` | ALB, groupe cible, enregistrements et listener |
| `outputs.tf` | DNS, URL et identifiants |
| `README.md` | Documentation |

## Entrées

| Variable | Type | Défaut | Description |
|---|---|---|---|
| `project_name` | `string` | `"moustapha"` | Nom du projet |
| `env` | `string` | `"dev"` | Environnement |
| `vpc_id` | `string` | Obligatoire | VPC du groupe cible |
| `security_group_id` | `string` | Obligatoire | Groupe de sécurité ALB |
| `instance_ids` | `list(string)` | Obligatoire | Identifiants des instances cibles |
| `subnet_ids` | `list(string)` | Obligatoire | Sous-réseaux publics de l'ALB |

Une liste vide d'instances est acceptée, mais le groupe cible
n'aura aucune instance pour servir l'application.

## Prérequis réseau

- Fournir au moins deux sous-réseaux publics dans des zones distinctes.
- Fournir un seul sous-réseau par zone sélectionnée.
- Les sous-réseaux doivent appartenir au VPC prévu.
- Les sous-réseaux publics doivent disposer d'une route vers
  l'Internet Gateway.
- Prévoir des sous-réseaux de taille suffisante, au moins /27,
  et au moins huit adresses IP libres par sous-réseau.
- Le groupe ALB doit autoriser les visiteurs sur TCP 80.
- Le groupe ALB doit autoriser les sorties vers Web sur TCP 80.
- Le groupe Web doit autoriser les entrées depuis le groupe ALB
  sur TCP 80.
- Les ACL réseau doivent également permettre les communications.

La validation Terraform proposée vérifie seulement le nombre
d'identifiants distincts, pas leurs zones ni leurs routes.

## Chemin des requêtes

1. Le visiteur contacte le DNS de l'ALB sur HTTP 80.
2. Le listener transmet la requête au groupe cible.
3. Le groupe cible sélectionne une instance utilisable.
4. L'instance reçoit la requête sur son port 80.

L'ALB contacte les instances via leurs adresses privées.
Une instance cible n'a pas besoin d'une IPv4 publique.

## Configuration du groupe cible

| Paramètre | Valeur |
|---|---|
| Type de cible | Instance EC2 |
| Protocole | HTTP |
| Port applicatif | 80 |
| Chemin du health check | `/` |
| Port du health check | Port du trafic : 80 |
| Intervalle | 30 secondes |
| Timeout | 5 secondes |
| Seuil de rétablissement | 2 succès consécutifs |
| Seuil de défaillance | 2 échecs consécutifs |
| Codes HTTP acceptés | 200 à 299 |
| Délai de drainage | 300 secondes |

La page `/` doit être accessible sans authentification
et retourner un code HTTP accepté.

Si l'application répond par une redirection ou une erreur
d'authentification, choisir un endpoint de santé approprié.

Lors de l'enregistrement initial, AWS peut déclarer une cible saine
après un premier contrôle réussi. Le seuil de rétablissement concerne
le retour à l'état sain d'une cible précédemment défaillante.

## Exemple d'appel

Depuis la configuration racine :

```hcl
module "alb" {
  source = "./modules/alb"

  project_name = "rendezvous-pki"
  env          = "dev"

  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security.alb_sg_id

  instance_ids = [module.ec2.instance_id]
}
```

Cet exemple suppose les modules VPC, Security et EC2 déjà déclarés.
Le fournisseur AWS reste à configurer dans la racine.

Les références aux sorties créent les dépendances implicites
vers les ressources concernées.

## Sorties

| Sortie | Description |
|---|---|
| `alb_dns` | Nom DNS du load balancer |
| `url_alb` | URL HTTP |
| `zone_id` | Zone AWS de l'ALB utilisée comme cible Alias Route 53 |
| `alb_arn` | ARN du load balancer |
| `target_group_arn` | ARN du groupe cible |

`zone_id` n'est pas l'identifiant de la zone DNS de ton propre domaine.

Les sorties doivent être relayées dans le module racine pour
être consultées directement avec `terraform output`.

## Vérifications

Depuis la racine :

```powershell
terraform fmt -recursive
terraform fmt -check -recursive
```

Après déclaration des exigences de fournisseur :

```powershell
terraform -chdir=modules/alb init -backend=false
terraform -chdir=modules/alb validate
```

Ces commandes ne créent pas l'ALB.

Après déploiement :

- vérifier le listener ;
- vérifier les instances enregistrées ;
- consulter leur état de santé ;
- tester l'URL HTTP depuis le poste.

Un service HTTP doit être installé et démarré sur les instances.
Le module EC2 ne réalise pas cette installation.

## Limites

- HTTP uniquement.
- Aucun listener HTTPS ni certificat.
- Aucune redirection HTTP vers HTTPS.
- Aucun chiffrement ALB vers Web.
- Aucun mTLS ni contrôle de révocation configuré.
- Aucun enregistrement Route 53 créé.
- Aucune installation applicative.
- Aucun Auto Scaling.
- Une seule instance ne fournit pas de redondance applicative.
- Réordonner `instance_ids` peut modifier les enregistrements
  gérés avec `count`.

Les noms ALB et groupe cible doivent respecter les contraintes AWS,
notamment leur longueur maximale de 32 caractères.

## Santé des cibles

Une infrastructure créée avec succès ne garantit pas
que l'application soit opérationnelle.

Si aucune cible n'est enregistrée, l'ALB peut retourner HTTP 503.

Si toutes les cibles enregistrées sont défaillantes, l'ALB peut
leur transmettre quand même le trafic : les contrôles de santé
ne constituent pas un mécanisme de sécurité.

## Coûts

L'ALB entraîne des frais, même lorsque le laboratoire reçoit peu
de trafic, notamment pour sa durée d'utilisation et sa capacité.

Examiner également les coûts des IPv4 publiques et des transferts.

## Références

- [ALB avec Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)
- [Application Load Balancers](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html)
- [Contrôles de santé des cibles](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)