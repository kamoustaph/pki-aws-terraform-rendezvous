# Module Security

## Fonction

Ce module Terraform crée les groupes de sécurité destinés au load balancer,
aux serveurs Web et à une base RDS de l'application de gestion de rendez-vous.

Il doit recevoir l'identifiant d'un VPC existant.

Il ne crée aucun ALB, serveur EC2 ou base RDS. Les groupes devront être
associés à ces ressources lors de leur création.

## État

Le code a été revu et commenté.

La validation Terraform et le déploiement restent à effectuer.
Aucun test de communication n'est confirmé à ce stade.

## Organisation

| Fichier | Rôle |
|---|---|
| `variables.tf` | Paramètres d'entrée |
| `main.tf` | Groupes et règles de sécurité |
| `outputs.tf` | Identifiants des groupes |
| `README.md` | Documentation |

Le nom `variable.tf` est également accepté par Terraform.

## Architecture réseau prévue

Les visiteurs accèdent à l'ALB sur les ports 80 et 443.

L'ALB transmet les requêtes aux serveurs Web sur le port 80.

Les serveurs Web peuvent joindre la base MySQL sur le port 3306.

L'accès SSH aux serveurs Web est désactivé par défaut.

## Entrées

| Variable | Type | Défaut | Description |
|---|---|---|---|
| `env` | `string` | `"dev"` | Environnement utilisé dans les noms |
| `project_name` | `string` | `"moustapha"` | Nom du projet |
| `vpc_id` | `string` | Aucun : obligatoire | Identifiant du VPC |
| `allowed_ssh_cidr` | `list(string)` | `[]` | Plages IPv4 autorisées pour SSH |

Chaque valeur de `allowed_ssh_cidr` doit être un CIDR IPv4 valide.

Les valeurs d'environnement ne sont pas limitées par une validation.

## Règles entrantes

| Groupe destination | Source | Protocole | Port |
|---|---|---|---|
| ALB | Toutes les adresses IPv4 | TCP | 80 |
| ALB | Toutes les adresses IPv4 | TCP | 443 |
| Web | Groupe ALB | TCP | 80 |
| Web | CIDR de `allowed_ssh_cidr` | TCP | 22 |
| RDS | Groupe Web | TCP | 3306 |

Avec la liste SSH vide, aucune règle entrante sur le port 22 n'est créée.

## Règles sortantes

| Groupe source | Destination | Trafic |
|---|---|---|
| ALB | Groupe Web | TCP 80 |
| Web | Toutes les destinations IPv4 | Tous les protocoles |
| RDS | Toutes les destinations IPv4 | Tous les protocoles |

Les groupes de sécurité sont stateful : les réponses à une communication
autorisée ne nécessitent pas une règle inverse dédiée.

Les règles de sortie générales Web et RDS pourront être restreintes
selon les besoins réels.

## Exemple d'appel

Depuis la configuration racine, après déclaration du module VPC :

```hcl
module "security" {
  source = "./modules/security"

  project_name = "rendezvous-pki"
  env          = "dev"
  vpc_id       = module.vpc.vpc_id

  allowed_ssh_cidr = []
}
```

La référence `module.vpc.vpc_id` transmet l'identifiant du VPC au module
Security et crée une dépendance implicite entre les modules.

Cette déclaration ne remplace pas la configuration du fournisseur AWS.

## Sorties

| Sortie | Description |
|---|---|
| `aws_sg_id` | Identifiant du groupe Web |
| `rds_sg_id` | Identifiant du groupe RDS |
| `alb_sg_id` | Identifiant du groupe ALB |

Exemples de références depuis la configuration racine :

```hcl
module.security.aws_sg_id
module.security.rds_sg_id
module.security.alb_sg_id
```

## Limites et points à confirmer

- La base est supposée utiliser MySQL sur le port 3306.
- Le service cible de l'ALB est supposé écouter sur le port 80.
- Le contrôle de santé de l'ALB doit également utiliser ce port,
  ou des règles supplémentaires seront nécessaires.
- Une application Spring Boot exposée directement sur 8080 nécessite
  une adaptation des règles ALB et Web.
- Le port HTTPS ouvert sur l'ALB ne configure ni certificat ni listener.
- Le lien ALB vers Web utilise HTTP ; le chiffrement interne et le mTLS
  ne sont pas encore configurés.
- Aucune règle spécifique à EJBCA, OCSP ou aux CRL n'est encore définie.
- Aucune règle IPv6 n'est créée.
- L'accès SSH nécessite aussi un chemin réseau vers le serveur.
- Les autres groupes éventuellement associés à une ressource peuvent
  lui accorder des accès supplémentaires.

## Gestion des règles

Les règles utilisent uniquement :

- `aws_vpc_security_group_ingress_rule` ;
- `aws_vpc_security_group_egress_rule`.

Ne pas ajouter de règles intégrées `ingress` ou `egress` dans ces mêmes
ressources `aws_security_group`, ni mélanger avec `aws_security_group_rule`.

## Vérifications

Depuis la racine du dépôt :

```powershell
terraform fmt -recursive
terraform fmt -check -recursive
```

Après déclaration des exigences de fournisseur :

```powershell
terraform -chdir=modules/security init -backend=false
terraform -chdir=modules/security validate
```

Ces commandes ne déploient aucune ressource.

La validation doit être complétée par l'examen d'un plan depuis la
configuration racine, puis par des tests réseau après déploiement.

## Références

- [Groupes de sécurité Terraform AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)
- [Groupes de sécurité des ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-update-security-groups.html)