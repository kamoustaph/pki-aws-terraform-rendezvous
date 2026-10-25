# PKI et application de gestion de rendez-vous sur AWS

Projet pédagogique de Moustapha associant une application Spring Boot / Angular à une infrastructure AWS décrite avec Terraform et à une PKI EJBCA / SoftHSM.

## État du projet

Le projet commence par la construction de modules Terraform pour le réseau AWS. L'application et la PKI sont développées séparément et seront intégrées progressivement.

Aucun déploiement AWS ni résultat de validation Terraform n'est confirmé à ce stade.

| Composant | État |
|---|---|
| Module VPC Terraform | Code commenté ; zones et route NAT corrigées ; validation à effectuer |
| Module security | Dossier créé ; contenu et rôle à documenter |
| Application de gestion de rendez-vous | Développement commencé ; intégration au dépôt à effectuer |
| EJBCA / SoftHSM / Docker | Travail existant séparé ; partie révocation en cours |
| Module racine appelant le VPC | À ajouter |
| Infrastructure EC2 | Prévue |
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
| `modules/security/` | Dossier créé ; contenu à examiner et documenter |

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

### Validation du module

Après ajout des exigences de fournisseur au module :

```powershell
terraform -chdir=modules/vpc init -backend=false
terraform -chdir=modules/vpc validate
```

Cette initialisation prépare les dépendances nécessaires à la validation sans initialiser un backend distant.

La validation ne garantit ni les permissions AWS, ni la disponibilité effective des ressources, ni la réussite d'un déploiement.

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
- Examiner et documenter le contenu du dossier `modules/security/`.

## Coûts et données sensibles

### Coûts AWS

Le déploiement peut entraîner des frais, notamment pour :

- la NAT Gateway ;
- l'adresse IPv4 publique ;
- le traitement et le transfert des données ;
- les futures instances EC2 ;
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
- les clés privées ;
- les sauvegardes de bases de données contenant des informations sensibles.

Le `.gitignore` constitue une aide, mais ne remplace pas une revue des fichiers avant chaque commit. Il ne retire pas automatiquement les fichiers déjà suivis par Git.

Le fichier `.terraform.lock.hcl` doit être versionné lorsqu'il est généré pour une configuration racine.

Les certificats publics et les chaînes de confiance ne sont pas des clés privées. Leur publication éventuelle doit néanmoins être intentionnelle.

## Feuille de route

- [x] Créer le dépôt GitHub.
- [x] Ajouter la documentation initiale.
- [x] Écrire et commenter le module VPC.
- [x] Corriger les zones par défaut et la cible de la route NAT.
- [ ] Valider le module VPC.
- [ ] Examiner et documenter le module security.
- [ ] Ajouter une configuration racine de développement.
- [ ] Examiner le plan et les coûts.
- [ ] Déployer et vérifier le réseau.
- [ ] Ajouter les ressources de calcul nécessaires à l'application.
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

- [Documentation Terraform](https://developer.hashicorp.com/terraform/docs)
- [Ressource Terraform AWS Route Table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table)
- [Régions AWS](https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html)

## Licence

Aucune licence de réutilisation n'est attribuée pour le moment. Une licence pourra être choisie avant diffusion plus large.