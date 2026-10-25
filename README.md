# PKI et application de gestion de rendez-vous sur AWS

Projet pédagogique de Moustapha associant une application Spring Boot / Angular à une infrastructure AWS décrite avec Terraform et à une PKI EJBCA / SoftHSM.

## État du projet

Le projet commence par la construction de modules Terraform pour le réseau, les groupes de sécurité, une base RDS MySQL, une instance EC2 et un Application Load Balancer sur AWS. L'application et la PKI sont développées séparément et seront intégrées progressivement.

Aucun déploiement des modules Terraform ni résultat de validation Terraform n'est confirmé à ce stade. Une paire de clés SSH a été créée manuellement et son existence a été vérifiée à Paris (`eu-west-3`).

| Composant | État |
|---|---|
| Module VPC Terraform | Code commenté ; zones et route NAT corrigées ; validation à effectuer |
| Module Security | Code revu ; version corrigée et commentée proposée ; application locale et validation à confirmer |
| Module RDS MySQL | Code initial examiné ; version corrigée et commentée proposée ; application locale et validation à confirmer |
| Application de gestion de rendez-vous | Développement commencé ; intégration au dépôt à effectuer |
| EJBCA / SoftHSM / Docker | Travail existant séparé ; partie révocation en cours |
| Configuration racine appelant les modules VPC, Security, RDS, EC2 et ALB | À ajouter |
| Module EC2 | Code initial examiné ; corrections et documentation proposées ; application locale et validation à confirmer |
| Module ALB | Code initial examiné ; version corrigée et commentée proposée ; application locale, validation et tests HTTP à confirmer |
| Paire de clés SSH EC2 | `terraformcloud` créée et vérifiée à Paris ; connexion SSH non testée |
| Configuration et déploiement Ansible | Prévus |
| Workflows GitHub Actions | Prévus |
| Intégration mTLS et contrôle de révocation | Prévus |

## Objectif

Construire une application de gestion de rendez-vous avec :

- une infrastructure AWS reproductible ;
- une organisation Terraform en modules ;
- des services exécutés dans Docker ;
- une configuration automatisée avec Ansible ;
- des workflows de vérification et de déploiement avec GitHub Actions ;
- une PKI EJBCA utilisant SoftHSM ;
- des communications internes sécurisées par certificats.

La partie PKI permettra d'étudier le cycle de vie des certificats : émission, renouvellement et révocation.

L'intégration mTLS devra permettre aux composants concernés de vérifier mutuellement leur identité.

## Responsabilités des outils

| Outil | Responsabilité prévue |
|---|---|
| AWS | Hébergement, réseau et stockage |
| Terraform | Création et gestion du cycle de vie des ressources AWS |
| Ansible | Configuration des serveurs et déploiement des services |
| Docker | Exécution des composants dans des conteneurs |
| GitHub Actions | Vérifications, construction des images et automatisation des déploiements |
| Spring Boot | API et logique métier de l'application |
| Angular | Interface utilisateur |
| EJBCA | Gestion des autorités de certification et des certificats |
| SoftHSM | Stockage et utilisation des clés de l'autorité via un token PKCS#11 logiciel |

SoftHSM est une implémentation logicielle utilisée pour l'apprentissage et les tests. Il n'offre pas les garanties de protection physique d'un HSM matériel.

## Structure actuelle

| Chemin | Rôle |
|---|---|
| `README.md` | Présentation générale et suivi du projet |
| `.gitignore` | Exclusion des fichiers locaux, états Terraform et données sensibles |
| `modules/vpc/main.tf` | Déclaration des ressources réseau |
| `modules/vpc/variables.tf` | Paramètres d'entrée du module VPC |
| `modules/vpc/outputs.tf` | Valeurs exposées par le module VPC |
| `modules/vpc/README.md` | Documentation du module VPC |
| `modules/security/main.tf` | Groupes et règles de sécurité ALB, Web et RDS |
| `modules/security/variable.tf` ou `variables.tf` | Paramètres du module Security ; conserver un seul de ces fichiers |
| `modules/security/outputs.tf` | Identifiants des groupes de sécurité |
| `modules/security/README.md` | Documentation proposée du module Security |
| `modules/rds/main.tf` | Groupe de sous-réseaux et instance RDS MySQL proposés |
| `modules/rds/variables.tf` | Paramètres du module RDS |
| `modules/rds/outputs.tf` | Identifiant et informations de connexion RDS |
| `modules/rds/README.md` | Documentation proposée du module RDS |
| `modules/ec2/main.tf` | Instance EC2 |
| `modules/ec2/variables.tf` | Paramètres de l'instance et de la commande SSH |
| `modules/ec2/outputs.tf` | Identifiant, adresses et commande SSH indicative |
| `modules/ec2/README.md` | Documentation proposée du module EC2 |
| `modules/alb/main.tf` | ALB public, groupe cible, enregistrements et listener HTTP |
| `modules/alb/variables.tf` | Paramètres du module ALB |
| `modules/alb/outputs.tf` | DNS, URL et identifiants ALB |
| `modules/alb/README.md` | Documentation proposée du module ALB |

Le dossier local `key/` contient les clés SSH et doit être exclu du dépôt avec `/key/` dans `.gitignore`. Il ne fait pas partie des fichiers à publier.

Les répertoires de l'application, de la PKI, d'Ansible et des workflows seront ajoutés lors de leur intégration.

Une configuration racine devra appeler les modules Terraform et définir le fournisseur AWS.

## Module réseau VPC

### Ressources décrites

Le module VPC décrit :

- un VPC avec résolution DNS et noms DNS activés ;
- des sous-réseaux publics ;
- des sous-réseaux privés ;
- une Internet Gateway ;
- une Elastic IP destinée à la NAT Gateway ;
- une NAT Gateway dans le premier sous-réseau public ;
- une table de routage publique ;
- une table de routage privée ;
- les associations entre les sous-réseaux et leurs tables de routage.

### Configuration par défaut

| Paramètre | Valeur |
|---|---|
| Nom du projet | `moustapha` |
| Environnement | `dev` |
| CIDR du VPC | `10.0.0.0/16` |
| Sous-réseaux publics | `10.0.1.0/24`, `10.0.2.0/24` |
| Sous-réseaux privés | `10.0.3.0/24`, `10.0.4.0/24` |
| Zones de disponibilité | `eu-west-3a`, `eu-west-3b` |
| Région cible | Paris : `eu-west-3` |

Ces valeurs peuvent être remplacées lors de l'appel du module.

La région doit être définie dans la configuration du fournisseur AWS. La liste des zones ne configure pas elle-même la région.

### Routage

Les sous-réseaux publics utilisent une route par défaut vers l'Internet Gateway.

Les sous-réseaux privés utilisent une route par défaut vers la NAT Gateway, avec l'attribut :

```hcl
nat_gateway_id = aws_nat_gateway.main.id
```

Cette configuration permet aux ressources privées d'initier des connexions IPv4 vers Internet et de recevoir les réponses, sous réserve des règles de sécurité.

Elle ne permet pas des connexions entrantes initiées depuis Internet vers ces ressources privées.

### Sorties du module

| Sortie | Description |
|---|---|
| `vpc_id` | Identifiant du VPC |
| `public_subnet_ids` | Liste des identifiants des sous-réseaux publics |
| `private_subnet_ids` | Liste des identifiants des sous-réseaux privés |

Ces sorties permettront aux autres modules de référencer le réseau créé.

### Limites actuelles

- Une seule NAT Gateway est partagée par les sous-réseaux privés.
- Cette NAT Gateway est située dans une seule zone de disponibilité.
- La configuration ne fournit donc pas une sortie NAT indépendante dans chaque zone.
- Au moins un sous-réseau public est nécessaire, car la NAT utilise `aws_subnet.public[0]`.
- Chaque liste de sous-réseaux doit contenir au plus autant d'éléments que la liste des zones.
- Les plages IP des sous-réseaux doivent appartenir au VPC et ne pas se chevaucher.
- Le module VPC ne crée aucun serveur ni service applicatif.

Cette topologie est destinée à un laboratoire et ne constitue pas à elle seule une architecture de production hautement disponible.

## Module Security

### Fonction et état

Le module Security est destiné à créer trois groupes de sécurité dans le VPC : ALB, Web et RDS. Il ne crée pas le load balancer, les instances EC2 ni la base RDS.

Le code initial a été examiné. Une version corrigée et commentée a été proposée ; son application dans les fichiers locaux et sa validation restent à confirmer. Les tableaux ci-dessous décrivent cette version proposée.

### Règles entrantes proposées

| Destination | Source | Protocole | Port |
|---|---|---|---|
| ALB | Toutes les adresses IPv4 | TCP | 80 |
| ALB | Toutes les adresses IPv4 | TCP | 443 |
| Web | Groupe ALB | TCP | 80 |
| Web | Plages définies dans `allowed_ssh_cidr` | TCP | 22 |
| RDS | Groupe Web | TCP | 3306 |

La valeur par défaut proposée pour `allowed_ssh_cidr` est `[]` : aucune règle SSH n'est créée. Un accès SSH éventuel nécessite également un chemin réseau vers le serveur.

### Règles sortantes proposées

| Source | Destination | Trafic |
|---|---|---|
| ALB | Groupe Web | TCP 80 |
| Web | Toutes les destinations IPv4 | Tous les protocoles |
| RDS | Toutes les destinations IPv4 | Tous les protocoles |

Les groupes de sécurité sont stateful : les réponses à une communication autorisée n'exigent pas une règle inverse dédiée.

### Entrées et sorties

| Entrée | Description | Défaut proposé |
|---|---|---|
| `env` | Environnement utilisé dans les noms | `dev` |
| `project_name` | Nom du projet | `moustapha` |
| `vpc_id` | Identifiant du VPC | Obligatoire |
| `allowed_ssh_cidr` | Liste des plages IPv4 autorisées pour SSH | `[]` |

| Sortie | Description |
|---|---|
| `aws_sg_id` | Identifiant du groupe Web |
| `rds_sg_id` | Identifiant du groupe RDS |
| `alb_sg_id` | Identifiant du groupe ALB |

La sortie Web doit utiliser `aws_security_group.web.id` pour retourner uniquement l'identifiant du groupe.

### Liaison prévue avec le module VPC

Dans la future configuration racine, après déclaration du module `vpc` :

```hcl
module "security" {
  source = "./modules/security"

  project_name     = "rendezvous-pki"
  env              = "dev"
  vpc_id           = module.vpc.vpc_id
  allowed_ssh_cidr = []
}
```

La référence `module.vpc.vpc_id` transmet l'identifiant du VPC et crée une dépendance implicite. Le fournisseur AWS doit aussi être déclaré et configuré dans la configuration racine.

### Hypothèses et limites

- Le service Web est supposé écouter sur le port 80, par exemple derrière Nginx. Si Spring Boot est exposé directement sur 8080, les règles devront être adaptées.
- Les contrôles de santé de l'ALB sont supposés utiliser le port 80 ; un autre port nécessitera une adaptation.
- La base est supposée utiliser MySQL sur le port 3306. Le moteur réel de l'application reste à confirmer ; PostgreSQL utilise habituellement le port 5432.
- Ouvrir le port 443 ne configure ni listener HTTPS ni certificat.
- La communication ALB vers Web utilise HTTP dans cette proposition. Le chiffrement interne et le mTLS seront traités lors de l'intégration PKI.
- Aucune règle spécifique à EJBCA, aux CRL ou à OCSP n'est encore définie.
- Les règles sont IPv4 uniquement.
- Les groupes doivent être associés aux futures ressources pour agir sur leurs communications. D'autres groupes associés peuvent accorder des accès supplémentaires.
- La version corrigée utilise uniquement des ressources `aws_vpc_security_group_ingress_rule` et `aws_vpc_security_group_egress_rule`. Ne pas les mélanger avec des règles intégrées aux mêmes groupes ni avec `aws_security_group_rule`.

## Module RDS MySQL

### Fonction et état

Le module RDS est destiné à créer un groupe de sous-réseaux et une instance MySQL pour l'application de gestion de rendez-vous. Il réutilise les sous-réseaux privés du module VPC et le groupe RDS du module Security.

Le code initial a été examiné. Les paramètres suivants décrivent la version corrigée proposée ; leur application locale, la validation et le déploiement restent à confirmer.

### Configuration proposée

| Paramètre | Valeur |
|---|---|
| Moteur et famille de version | MySQL `8.0`, disponibilité et support à vérifier |
| Groupe de paramètres | `default.mysql8.0` |
| Classe d'instance | `db.t3.micro`, compatibilité régionale à vérifier |
| Stockage initial | 20 Gio, `gp3` |
| Chiffrement du stockage | Activé |
| Accès public | Désactivé |
| Multi-AZ | Désactivé |
| Sauvegardes automatisées | Désactivées : rétention de 0 jour |
| Protection contre la suppression | Désactivée |
| Snapshot final | Désactivé |

Cette configuration est réservée à un laboratoire avec des données jetables. Elle n'offre ni instance de secours Multi-AZ, ni sauvegarde automatisée, ni snapshot final. La version moteur et son éventuel support étendu doivent être examinés avant le déploiement.

Le chiffrement du stockage ne configure pas à lui seul TLS sur les connexions MySQL. Aucune intégration entre RDS et la PKI EJBCA n'est réalisée ici.

### Entrées et sorties

| Entrée | Description | Défaut proposé |
|---|---|---|
| `env` | Environnement | `dev` |
| `project_name` | Nom du projet | `moustapha` |
| `security_group_id` | Identifiant du groupe de sécurité RDS | Obligatoire |
| `subnet_ids` | Liste des sous-réseaux privés | Obligatoire |
| `db_name` | Nom de la base MySQL initiale | `moustaphadb` |
| `db_username` | Compte administrateur initial | `admin` |
| `db_password` | Mot de passe administrateur sensible | Obligatoire, sans valeur par défaut |

La variable `vpc_id`, inutilisée dans le code initial, est retirée de la version proposée. Le VPC est déterminé par les sous-réseaux fournis. Le groupe de sécurité doit appartenir à ce même VPC.

| Sortie | Description |
|---|---|
| `rds_endpoint` | Nom DNS et port au format `adresse:port` |
| `rds_instance_id` | Identifiant de l'instance RDS |
| `rds_address` | Nom DNS sans port |
| `rds_port` | Port MySQL |

### Liaison prévue avec VPC et Security

Dans la future configuration racine, après déclaration des modules `vpc` et `security` :

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

Cet exemple n'est pas une configuration racine complète. La variable racine `db_password` doit être déclarée une seule fois et sa valeur fournie hors du code versionné.

### Prérequis et limites

- Les sous-réseaux doivent appartenir au même VPC et couvrir au moins deux zones, même si `multi_az` vaut `false`.
- La validation proposée vérifie le nombre de sous-réseaux distincts, pas leurs zones ni leur VPC.
- Le groupe RDS doit autoriser TCP 3306 depuis les ressources applicatives.
- L'application doit disposer d'un chemin réseau privé vers la base. Une connexion directe depuis le poste local n'est pas fournie par ce module.
- La compatibilité de l'application existante avec MySQL reste à confirmer.
- Le compte administrateur doit être complété par un compte applicatif aux permissions limitées.
- Ce module ne crée ni les tables métier, ni les migrations, ni les données de l'application.
- Les noms de projet et d'environnement doivent être compatibles avec les contraintes de nommage RDS.
- `sensitive = true` masque l'affichage courant du mot de passe ; avec l'argument `password`, celui-ci reste enregistré dans l'état Terraform.
- Les politiques EC2 et S3 seules ne donnent pas les permissions de création RDS. Les droits RDS et les éventuelles dépendances IAM/KMS doivent être vérifiés.

## Module EC2

### Fonction et état

Le module EC2 décrit une instance Linux à partir d'une AMI fournie. Il utilise un sous-réseau du module VPC et les groupes du module Security.

Le code initial a été examiné et une version corrigée et commentée a été proposée. Son application locale, la validation, le déploiement et le test SSH restent à confirmer. La présence du code ne signifie pas qu'une instance est déjà créée.

### Entrées proposées

| Entrée | Description | Défaut |
|---|---|---|
| `ami` | Identifiant d'une AMI régionale compatible | Obligatoire |
| `instance_type` | Type d'instance | `t2.micro`, disponibilité et coût à vérifier |
| `subnet_id` | Sous-réseau d'accueil | Obligatoire |
| `security_group_ids` | Liste des groupes de sécurité du même VPC | Obligatoire |
| `key_name` | Nom de la paire de clés existante dans AWS | `terraformcloud` |
| `ssh_user` | Compte Linux de connexion | `ubuntu` |
| `private_key_path` | Chemin local utilisé pour afficher la commande SSH | `./key/terraformcloud.pem` |
| `env` | Environnement | `dev` |
| `project_name` | Nom du projet | `moustapha` |

Le module corrigé utilise `vpc_security_group_ids` pour associer les groupes par leurs identifiants. Le compte `ubuntu` suppose une AMI Ubuntu ; une AMI Amazon Linux utilise habituellement `ec2-user`.

### Sorties proposées

| Sortie | Description |
|---|---|
| `ec2_public_ip` | IPv4 publique, si disponible |
| `public_dns` | Nom DNS public, si disponible |
| `instance_id` | Identifiant EC2 |
| `ec2_private_ip` | IPv4 privée |
| `ssh_command` | Commande SSH publique indicative, ou `null` sans IPv4 publique |

Les sorties du module enfant doivent être relayées dans la configuration racine pour être consultées directement avec `terraform output`.

### Paire de clés confirmée

La commande AWS CLI a confirmé l'existence de la paire RSA `terraformcloud` dans la région Paris (`eu-west-3`).

La clé privée utilisée doit être celle téléchargée lors de cette création à Paris. L'ancien fichier correspondant à une paire créée à Stockholm ne permet pas de s'authentifier avec cette nouvelle paire.

Le nom AWS `key_name` et le chemin local `private_key_path` ont des rôles distincts. Le module proposé ne lit pas le fichier privé et ne l'envoie pas à AWS. Il ne crée pas la paire de clés.

### Exemple d'appel pour un laboratoire avec SSH direct

Après déclaration des modules VPC et Security dans la configuration racine :

```hcl
variable "ec2_ami" {
  type        = string
  description = "AMI Ubuntu compatible disponible dans eu-west-3."
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

Cet exemple n'est pas une configuration racine complète. L'AMI réelle et le fournisseur AWS restent à configurer.

### Conditions pour SSH

- Le poste doit pouvoir joindre l'instance sur TCP 22.
- Pour un accès direct depuis Internet, l'instance doit disposer d'une adresse publique et d'une route via l'Internet Gateway.
- Le module EC2 proposé n'impose pas d'IPv4 publique : son attribution dépend du sous-réseau. Le module VPC active cette attribution dans ses sous-réseaux publics.
- Le module Security désactive SSH par défaut avec `allowed_ssh_cidr = []`. Autoriser explicitement l'IPv4 publique réelle du poste en `/32` dans l'appel de ce module si nécessaire.
- Les ACL réseau et le service SSH doivent permettre la connexion.
- La clé privée doit correspondre à la paire AWS et avoir des permissions Windows acceptées par OpenSSH.
- Le chemin relatif de la clé doit être valide depuis le dossier où la commande SSH est exécutée.

Une instance privée nécessite un accès d'administration adapté, par exemple un bastion, un VPN ou Session Manager configuré. Une NAT Gateway ne fournit pas d'accès SSH entrant depuis Internet.

### Limites

Le module n'installe ni Docker, ni Nginx, ni l'application. La configuration sera traitée avec Ansible. Aucun ALB, rôle IAM d'instance, Elastic IP ou certificat n'est créé par ce module.

La création du groupe ALB dans le module Security ne crée pas le load balancer lui-même. Le futur trafic applicatif reste prévu via l'ALB ; l'exemple EC2 public concerne l'administration du laboratoire.

## Module ALB

### Fonction et état

Le module ALB décrit un Application Load Balancer public, un groupe cible d'instances EC2, leurs enregistrements et un listener HTTP sur le port 80.

Le code initial a été examiné. Une version corrigée et commentée utilisant les ressources `aws_lb`, `aws_lb_target_group`, `aws_lb_target_group_attachment` et `aws_lb_listener` a été proposée. Son application locale, sa validation, son déploiement et les tests HTTP restent à confirmer.

### Entrées

| Entrée | Type | Défaut proposé | Description |
|---|---|---|---|
| `project_name` | `string` | `moustapha` | Nom du projet |
| `env` | `string` | `dev` | Environnement |
| `vpc_id` | `string` | Obligatoire | VPC du groupe cible |
| `security_group_id` | `string` | Obligatoire | Groupe de sécurité ALB |
| `instance_ids` | `list(string)` | Obligatoire | Instances EC2 à enregistrer |
| `subnet_ids` | `list(string)` | Obligatoire | Sous-réseaux publics de l'ALB |

Une liste vide d'instances est acceptée mais ne fournit aucune cible pour servir l'application. Le module utilise `count` pour les enregistrements : conserver un ordre stable dans `instance_ids`.

### Configuration proposée

| Paramètre | Valeur |
|---|---|
| Type | Application Load Balancer |
| Exposition | Publique : `internal = false` |
| Listener | HTTP, port 80 |
| Protocole et port vers les instances | HTTP, port 80 |
| Type de cible | `instance` |
| Chemin du contrôle de santé | `/` |
| Port du contrôle | Port du trafic : 80 |
| Intervalle / timeout | 30 / 5 secondes |
| Seuil de rétablissement / défaillance | 2 succès / 2 échecs consécutifs |
| Codes HTTP acceptés | 200 à 299 |
| Délai de drainage | 300 secondes |

La page `/` doit être accessible sans authentification et retourner un code accepté. Une redirection 301/302 ou une réponse 401 échoue avec ce matcher. Un endpoint de santé dédié pourra être choisi selon l'application.

Le seuil de rétablissement concerne une cible précédemment défaillante. À l'enregistrement initial, AWS peut déclarer une cible saine après un premier contrôle réussi.

### Sorties

| Sortie | Description |
|---|---|
| `alb_dns` | Nom DNS du load balancer |
| `url_alb` | URL HTTP exposée |
| `zone_id` | Zone AWS de l'ALB utilisée comme cible Alias Route 53 |
| `alb_arn` | ARN du load balancer |
| `target_group_arn` | ARN du groupe cible |

`zone_id` n'est pas l'identifiant de la zone DNS de ton propre domaine. Le module ne crée aucun enregistrement Route 53.

### Liaison prévue avec les autres modules

Dans la configuration racine, après déclaration de VPC, Security et EC2 :

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

Cet exemple n'est pas une configuration racine complète. Les références aux sorties établissent les dépendances implicites. Le fournisseur AWS reste à configurer.

### Chemin des requêtes et prérequis

1. Le visiteur contacte le DNS public de l'ALB sur le port 80.
2. Le listener transmet la requête au groupe cible.
3. L'ALB contacte l'instance sur son adresse privée et son port 80.
4. Le service Web traite la requête et renvoie la réponse.

Le module ALB doit recevoir des sous-réseaux publics dans au moins deux zones distinctes, avec un seul sous-réseau par zone sélectionnée. Pour cette architecture, prévoir des sous-réseaux de taille /27 ou supérieure et au moins huit adresses libres par sous-réseau. Les sous-réseaux publics doivent avoir une route vers l'Internet Gateway.

Le groupe ALB doit autoriser les entrées TCP 80 et les sorties TCP 80 vers le groupe Web. Le groupe Web doit accepter TCP 80 depuis le groupe ALB. Les ACL réseau doivent également permettre les flux et leurs réponses.

L'ALB public peut cibler une instance privée. Une IPv4 publique sur l'instance n'est pas nécessaire au trafic ALB vers Web. Le choix d'une instance publique dans l'exemple EC2 précédent concerne uniquement l'administration du laboratoire.

### Limites et tests applicatifs

- HTTP uniquement : aucun listener HTTPS, certificat, chiffrement ALB vers Web ni mTLS n'est configuré.
- Ouvrir le port 443 dans le groupe Security ne crée pas de listener HTTPS.
- Aucun service Web n'est installé par ce module ou le module EC2. Ansible devra installer/configurer le service, ou un serveur HTTP de test devra être préparé.
- Si Spring Boot écoute directement sur 8080, adapter le groupe cible, les enregistrements et les règles réseau ensemble.
- Une seule instance EC2 reste un point de panne unique ; deux zones pour l'ALB ne créent pas deux serveurs applicatifs.
- Sans cible enregistrée, l'ALB peut retourner HTTP 503.
- Si toutes les cibles enregistrées sont défaillantes, l'ALB peut leur envoyer le trafic malgré tout. Les health checks ne constituent pas un contrôle de sécurité.
- Les noms de l'ALB et du groupe cible doivent respecter les contraintes AWS, notamment la limite de 32 caractères.
- Aucune règle de routage par chemin ni politique Auto Scaling n'est ajoutée.

## Prérequis

- Terraform installé.
- Git installé.
- AWS CLI installé.
- Un compte AWS avec les permissions adaptées aux ressources prévues.
- Un profil AWS local fonctionnel.
- VS Code avec l'extension HashiCorp Terraform, recommandé.

Le profil AWS actuellement utilisé sur le poste de développement est nommé `terraform`.

Les fichiers de configuration et d'identification AWS restent sur le poste et ne doivent pas être copiés dans le dépôt.

GitHub Actions utilisera ultérieurement une authentification AWS par OIDC, distincte de la connexion locale.

## Vérifications locales

### Formatage

Depuis la racine du dépôt :

```powershell
terraform fmt -recursive
```

Vérifier ensuite que le formatage est conforme :

```powershell
terraform fmt -check -recursive
```

Ces commandes ne créent aucune ressource AWS.

### Vérification de l'identité AWS

```powershell
aws sts get-caller-identity --profile terraform
```

Le résultat doit correspondre à l'utilisateur IAM prévu pour le projet.

Cette commande vérifie l'identité utilisée ; elle ne garantit pas les permissions nécessaires à toutes les ressources.

### Vérification des zones de disponibilité

```powershell
aws ec2 describe-availability-zones --region eu-west-3 --profile terraform --query "AvailabilityZones[].ZoneName" --output table
```

Vérifier que les zones configurées dans le module sont disponibles pour le compte.

### Validation des modules

Après ajout des exigences de fournisseur à chaque module :

```powershell
terraform -chdir=modules/vpc init -backend=false
terraform -chdir=modules/vpc validate

terraform -chdir=modules/security init -backend=false
terraform -chdir=modules/security validate

terraform -chdir=modules/rds init -backend=false
terraform -chdir=modules/rds validate

terraform -chdir=modules/ec2 init -backend=false
terraform -chdir=modules/ec2 validate

terraform -chdir=modules/alb init -backend=false
terraform -chdir=modules/alb validate
```

Cette initialisation prépare les dépendances nécessaires à la validation sans initialiser un backend distant.

La validation ne garantit ni les permissions AWS, ni la disponibilité effective des ressources, ni la réussite d'un déploiement.

### Vérifications RDS avant le plan

Lister les versions MySQL proposées dans la région :

```powershell
aws rds describe-db-engine-versions --engine mysql --region eu-west-3 --profile terraform --query "DBEngineVersions[].{Version:EngineVersion,Famille:DBParameterGroupFamily}" --output table
```

Après sélection d'une version exacte, vérifier la classe `db.t3.micro` avec `aws rds describe-orderable-db-instance-options` pour cette version et la région. Ne pas supposer que la famille `8.0` est le meilleur choix : examiner son support, les coûts et la compatibilité applicative. Tout changement de version majeure doit rester cohérent avec le groupe de paramètres.

Ces vérifications nécessitent des permissions de lecture RDS ; une erreur `AccessDenied` devra être résolue avant de poursuivre.

### Vérifications EC2 et SSH

Vérifier la paire de clés dans la région cible :

```powershell
aws ec2 describe-key-pairs --key-names terraformcloud --region eu-west-3 --profile terraform
```

Cette vérification a réussi pour `terraformcloud` à Paris. Elle ne valide ni le fichier privé local ni une connexion SSH.

Avant déploiement, confirmer l'AMI, son architecture et sa compatibilité avec le type d'instance.

Vérifier l'exclusion du dossier local de clés :

```powershell
git check-ignore -v key/terraformcloud.pem
git ls-files key/
```

La seconde commande ne doit afficher aucun fichier. Si elle en affiche, retirer le dossier du suivi avec `git rm -r --cached -- key/`, sans supprimer les fichiers locaux. Une clé privée déjà publiée doit être remplacée ; `.gitignore` ne nettoie pas l'historique.

Si la session AWS expire, renouveler la connexion :

```powershell
aws login --profile moustapha-login --region eu-west-3
aws sts get-caller-identity --profile terraform
```

Sélectionner l'utilisateur IAM prévu pour le projet, et non la session root.

### Vérifications ALB après déploiement

Vérifier le listener HTTP, les instances enregistrées et leur état de santé depuis la console EC2, rubrique Groupes cibles. Le rôle ou l'utilisateur AWS doit disposer des permissions Elastic Load Balancing nécessaires.

Pour consulter la santé des cibles en ligne de commande :

```powershell
# Remplacer cette valeur par l'ARN réel obtenu après déploiement.
$targetGroupArn = "ARN_REEL_DU_GROUPE_CIBLE"
aws elbv2 describe-target-health --target-group-arn $targetGroupArn --region eu-west-3 --profile terraform
```

Après exposition de l'URL par un output de la configuration racine :

```hcl
output "url_alb" {
  description = "URL HTTP de l'application via ALB."
  value       = module.alb.url_alb
}
```

```powershell
$albUrl = terraform output -raw url_alb
Invoke-WebRequest -Uri $albUrl -UseBasicParsing
```

Ces tests s'effectuent après déploiement et installation du service HTTP. Aucun résultat de santé ou de test HTTP n'est confirmé pour le moment.

### Plan de déploiement

Après création de la configuration racine, un `terraform plan` permettra d'examiner les ressources à créer, modifier ou supprimer.

Aucun déploiement ne doit être considéré comme réalisé avant confirmation de son résultat.

## Corrections réalisées et vérifications restantes

### Corrections réalisées dans le code partagé

- Remplacement des zones incorrectes par `eu-west-3a` et `eu-west-3b`.
- Utilisation de `nat_gateway_id` dans la route privée.
- Ajout de commentaires explicatifs dans les fichiers Terraform.
- Documentation des variables et des sorties du module.

### Vérifications restantes

- Vérifier les zones disponibles dans le compte.
- Vérifier les longueurs des listes de sous-réseaux et de zones.
- Vérifier la cohérence et l'absence de chevauchement des CIDR.
- Vérifier l'encodage UTF-8 des fichiers.
- Déclarer les exigences de fournisseur.
- Exécuter le formatage et la validation Terraform.
- Ajouter la configuration racine.
- Examiner le plan et les coûts avant tout déploiement.
- Appliquer et vérifier la version corrigée proposée du module Security.
- Confirmer le moteur de base de données et les ports de l'application et des contrôles de santé.
- Vérifier les associations des groupes aux futures ressources et tester les flux autorisés et interdits.

### Revue du module Security

Les corrections proposées sont :

- retourner `aws_security_group.web.id` dans la sortie `aws_sg_id` ;
- remplacer le mélange de règles intégrées et séparées par des ressources de règles séparées ;
- limiter le trafic HTTP entrant sur Web au groupe ALB ;
- autoriser les connexions sortantes de l'ALB vers Web sur le port 80 ;
- désactiver SSH par défaut et n'autoriser que les plages explicitement fournies.

Ces modifications changent les règles réseau du code initial. Si une ancienne version a déjà été déployée, examiner les suppressions et créations proposées par le plan avant application.

### Revue du module RDS

Les corrections et ajustements proposés sont :

- utiliser le type `aws_db_subnet_group` et corriger sa référence ;
- référencer `aws_db_instance.main` dans les sorties ;
- remplacer le nom initial `moustapha_db` par `moustaphadb` ;
- retirer le mot de passe par défaut et la variable `vpc_id` inutilisée ;
- différencier les noms des ressources par projet et environnement ;
- déclarer le stockage `gp3` et activer son chiffrement ;
- ajouter les sorties DNS et port séparés ;
- documenter les limites des sauvegardes et de la suppression.

Si une instance existe déjà, examiner le plan avant ces modifications : les changements de nom, de base initiale ou de chiffrement peuvent nécessiter un remplacement. Les sauvegardes doivent être préparées avant toute modification destructive.

### Revue du module EC2

Les corrections et ajouts proposés sont :

- remplacer `security_groups` par `vpc_security_group_ids` ;
- distinguer le nom de la paire AWS du chemin du fichier privé local ;
- rendre l'utilisateur SSH et le chemin de clé paramétrables ;
- ajouter la sortie IPv4 privée ;
- ne pas afficher de commande SSH publique exploitable lorsque l'instance n'a pas d'IPv4 publique ;
- documenter les prérequis réseau et l'exclusion du dossier `key/`.

L'existence de la paire de clés à Paris est confirmée. La disponibilité de l'AMI, les permissions du fichier privé, la validation Terraform et la connexion SSH restent à vérifier.

### Revue du module ALB

Les corrections et clarifications proposées sont :

- rendre les types de ressources et les références cohérents en utilisant `aws_lb` partout ;
- corriger les descriptions copiées depuis le module RDS ;
- demander les sous-réseaux publics pour cet ALB Internet ;
- ajouter une validation du nombre de sous-réseaux distincts ;
- expliciter le type de cible `instance` et les contrôles de santé ;
- documenter les sorties DNS, URL, zone AWS et ARN ;
- distinguer le déploiement de l'infrastructure de la disponibilité de l'application.

Les noms `aws_alb` ne sont pas présentés ici comme une erreur en eux-mêmes : le problème du code initial était leur incohérence avec les sorties `aws_lb.main`. Si une ancienne version a déjà été appliquée, préparer et examiner la migration de l'état avant de changer les types de ressources. Ne pas supposer que le renommage sera sans effet sur le plan.

## Coûts et données sensibles

### Coûts AWS

Le déploiement peut entraîner des frais, notamment pour :

- la NAT Gateway ;
- l’ALB, sa durée d’utilisation et sa capacité ;
- l'adresse IPv4 publique ;
- le traitement et le transfert des données ;
- les futures instances EC2 ;
- l’instance RDS, son stockage et les éventuels frais de support étendu du moteur ;
- les volumes et services de stockage.

Examiner les tarifs AWS et le plan Terraform avant tout `terraform apply`.

La présence du code dans GitHub ne crée aucune ressource AWS à elle seule.

### Protection des données sensibles

Ne pas publier :

- les états Terraform et leurs sauvegardes ;
- les plans Terraform enregistrés ;
- les clés d'accès et secrets AWS ;
- les mots de passe ;
- les PIN SoftHSM ;
- les fichiers de tokens SoftHSM ;
- les clés privées, notamment les fichiers du dossier local `key/` ;
- les sauvegardes de bases de données contenant des informations sensibles.

Le `.gitignore` constitue une aide, mais ne remplace pas une revue des fichiers avant chaque commit. Il ne retire pas automatiquement les fichiers déjà suivis par Git.

Le mot de passe RDS ne doit pas être écrit dans le code ni dans un fichier suivi par Git. Avec la configuration proposée, il reste présent dans l’état Terraform malgré son marquage sensible. Un stockage d’état protégé est nécessaire.

Le fichier `.terraform.lock.hcl` doit être versionné lorsqu'il est généré pour une configuration racine.

Les certificats publics et les chaînes de confiance ne sont pas des clés privées. Leur publication éventuelle doit néanmoins être intentionnelle.

## Feuille de route

- [x] Créer le dépôt GitHub.
- [x] Ajouter la documentation initiale.
- [x] Écrire et commenter le module VPC.
- [x] Corriger les zones par défaut et la cible de la route NAT.
- [ ] Valider le module VPC.
- [x] Examiner le code initial du module Security.
- [x] Proposer les corrections, les commentaires et la documentation du module Security.
- [ ] Appliquer et vérifier les fichiers corrigés du module Security.
- [ ] Valider le module Security.
- [ ] Confirmer les ports applicatifs et le moteur de base de données.
- [ ] Associer les groupes aux ressources et tester les communications après déploiement.
- [x] Examiner le code initial du module RDS.
- [x] Proposer les corrections, les commentaires et la documentation RDS.
- [ ] Appliquer et vérifier les fichiers corrigés du module RDS.
- [ ] Valider le module RDS.
- [ ] Vérifier la version MySQL, son support et la classe disponible dans la région.
- [ ] Vérifier les permissions AWS nécessaires à RDS.
- [ ] Définir la gestion du secret administrateur et du compte applicatif.
- [x] Examiner le code initial du module EC2.
- [x] Proposer les corrections, les commentaires et la documentation EC2.
- [x] Créer et vérifier la paire RSA `terraformcloud` à Paris.
- [ ] Vérifier l'exclusion de `key/` et l'absence de clés privées suivies dans Git.
- [ ] Vérifier le nouveau fichier privé local et ses permissions Windows.
- [ ] Confirmer l'AMI, son architecture et le type d'instance.
- [ ] Appliquer et valider le module EC2 corrigé.
- [x] Examiner le code initial du module ALB.
- [x] Proposer les corrections, les commentaires et la documentation ALB.
- [ ] Appliquer les corrections et valider le module ALB.
- [ ] Relier ALB à VPC, Security et EC2 dans la configuration racine.
- [ ] Ajouter une configuration racine de développement appelant VPC, Security, RDS, EC2 et ALB.
- [ ] Déployer RDS et tester la connexion depuis le serveur applicatif.
- [ ] Examiner le plan et les coûts.
- [ ] Déployer et vérifier le réseau.
- [ ] Déployer EC2 et vérifier la connexion SSH.
- [ ] Déployer l'ALB et ses enregistrements de cibles.
- [ ] Installer un service HTTP sur l'instance pour les tests.
- [ ] Vérifier la santé des cibles et tester l'URL HTTP.
- [ ] Ajouter HTTPS et définir l'architecture de chiffrement interne.
- [ ] Ajouter les contrôles Terraform dans GitHub Actions.
- [ ] Configurer l'accès AWS OIDC et la gestion de l'état distant avant les déploiements CI.
- [ ] Configurer les serveurs avec Ansible.
- [ ] Déployer l'application avec Docker.
- [ ] Intégrer EJBCA et SoftHSM existants.
- [ ] Mettre en place le mTLS.
- [ ] Configurer la vérification de révocation par les composants concernés.
- [ ] Vérifier le rejet effectif d'un certificat révoqué.
- [ ] Documenter le renouvellement, les sauvegardes et la restauration.

## Références

- [ALB avec Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)
- [Application Load Balancers](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html)
- [Contrôles de santé des cibles ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)
- [Instance EC2 avec Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance)
- [Paires de clés EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)
- [Instance RDS avec Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)
- [Groupe de sous-réseaux RDS avec Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group)
- [RDS dans un VPC](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)
- [Versions RDS MySQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/MySQL.Concepts.VersionMgmt.html)
- [Documentation Terraform](https://developer.hashicorp.com/terraform/docs)
- [Ressource Terraform AWS Route Table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table)
- [Groupes de sécurité Terraform AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)
- [Groupes de sécurité des ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-update-security-groups.html)
- [Régions AWS](https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html)

## Licence

Aucune licence de réutilisation n'est attribuée pour le moment. Une licence pourra être choisie avant diffusion plus large.
