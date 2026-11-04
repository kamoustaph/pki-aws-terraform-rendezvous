# Module `app`

Prépare tout ce dont les instances EC2 ont besoin pour faire tourner l'application **Yoon**
(API Spring Boot + frontend Angular servi par nginx), sans créer d'instance lui-même.

| Responsabilité | Ressources |
|---|---|
| Secrets et paramètres de l'application | `aws_ssm_parameter` sous `/yoon/<env>/` |
| Clés générées (JWT, QR) | `random_password` |
| Identité des instances | `aws_iam_role`, `aws_iam_instance_profile`, politiques attachées |
| Démarrage des instances | user data rendu depuis `user_data.sh.tftpl`, avec `deploy.sh` |

Le module [`ec2`](../ec2/README.md) reçoit ensuite le profil IAM et le user data.
La documentation complète du déploiement est dans [`docs/DEPLOIEMENT-YOON.md`](../../docs/DEPLOIEMENT-YOON.md).

## Utilisation

```hcl
module "app" {
  source = "../../modules/app"

  project_name = var.project_name
  env          = var.env
  region       = var.region

  db_host     = module.rds.rds_address
  db_port     = module.rds.rds_port
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  demo_data = var.demo_data
}

module "ec2-1" {
  source = "../../modules/ec2"
  # ...
  user_data            = module.app.user_data["primary"]
  iam_instance_profile = module.app.instance_profile_name
}
```

## Entrées

| Variable | Type | Défaut | Description |
|---|---|---|---|
| `project_name` | string | `moustapha` | Nom du projet (tags) |
| `env` | string | requis | Environnement ; préfixe des paramètres `/yoon/<env>/` |
| `region` | string | requis | Région du registre ECR et des paramètres SSM |
| `api_repository` | string | `gestion-voyage-api` | Registre ECR de l'API |
| `web_repository` | string | `gestion-voyage-web` | Registre ECR du frontend |
| `image_tag` | string | `latest` | Tag lancé au premier démarrage |
| `db_host` | string | requis | Adresse RDS, sans le port |
| `db_port` | number | `3306` | Port MySQL |
| `db_name` | string | requis | Nom de la base |
| `db_username` | string | requis | Compte MySQL de l'API |
| `db_password` | string (sensible) | requis | Mot de passe MySQL |
| `demo_data` | bool | `false` | Données de démonstration au premier démarrage |
| `cors_allowed_origins` | string | `""` | Origines CORS supplémentaires ; vide si même domaine |
| `java_max_heap` | string | `384m` | Mémoire maximale de la JVM (t3.micro : 1 Go) |

## Sorties

| Sortie | Description |
|---|---|
| `instance_profile_name` | Profil IAM à passer au module `ec2` |
| `user_data` | Map `{ primary, secondary }` des scripts de démarrage |
| `ssm_prefix` | `/yoon/<env>` |
| `ecr_registry` | `<compte>.dkr.ecr.<région>.amazonaws.com` |

## Paramètres SSM créés

| Nom | Type |
|---|---|
| `/yoon/<env>/db_password` | SecureString |
| `/yoon/<env>/jwt_secret` | SecureString (généré) |
| `/yoon/<env>/qr_secret` | SecureString (généré) ; le changer invalide les billets émis |
| `/yoon/<env>/db_url` | String |
| `/yoon/<env>/db_username` | String |
| `/yoon/<env>/demo_data` | String |
| `/yoon/<env>/cors_allowed_origins` | String (`none` si vide : SSM refuse les valeurs vides) |
| `/yoon/<env>/java_max_heap` | String |

## Rôle des instances `yoon-<env>-ec2-role`

- `AmazonSSMManagedInstanceCore` : commandes de déploiement et Session Manager.
- `AmazonEC2ContainerRegistryReadOnly` : `docker pull`.
- Lecture des seuls paramètres `/yoon/<env>/*`, et `kms:Decrypt` limité aux appels passant par SSM.

## Primary et secondary

Les deux scripts sont identiques sauf `INSTANCE_ROLE`.
Seule l'instance `primary` peut créer les données de démonstration,
pour éviter deux insertions simultanées dans la même base.

## Fichiers

| Fichier | Rôle |
|---|---|
| `main.tf` | Paramètres SSM, IAM, rendu du user data |
| `variables.tf`, `outputs.tf`, `versions.tf` | Interface du module |
| `user_data.sh.tftpl` | Premier démarrage : swap, Docker, AWS CLI, agent SSM, premier lancement |
| `deploy.sh` | Copié dans `/opt/yoon/deploy.sh` ; (re)lance `api` et `web` |

## Points d'attention

- Les valeurs des paramètres sont aussi dans le state Terraform : le bucket du state doit rester privé.
- Le user data ne s'exécute qu'au premier démarrage ; le module `ec2` utilise `user_data_replace_on_change`
  pour recréer l'instance si le script change.
- Si les images ne sont pas encore dans ECR, le démarrage continue sans conteneur ;
  `sudo /opt/yoon/deploy.sh` les lancera plus tard.
