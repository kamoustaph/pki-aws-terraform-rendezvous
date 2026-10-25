# PKI et application de gestion de rendez-vous sur AWS

Projet pédagogique de Moustapha associant une application Spring Boot / Angular à une infrastructure AWS décrite avec Terraform et à une PKI EJBCA / SoftHSM.

## État du projet

Ce dépôt démarre par le module réseau Terraform. Aucun déploiement AWS ni test automatisé n'est attesté dans cette documentation.

| Composant | État |
|---|---|
| Module VPC Terraform | Code initial écrit ; corrections et validation à effectuer |
| Application de gestion de rendez-vous | Développement commencé ; intégration au dépôt à effectuer |
| EJBCA / SoftHSM / Docker | Travail existant séparé ; partie révocation en cours |
| Module racine appelant le VPC | À ajouter |
| EC2, déploiement Ansible, GitHub Actions | Prévus |
| Intégration mTLS et contrôle de révocation | Prévus |

## Objectif

Construire progressivement une application de gestion de rendez-vous, une infrastructure reproductible et un processus de déploiement automatisé. La PKI doit permettre l'authentification par certificats entre composants et l'étude de leur cycle de vie : émission, renouvellement et révocation.

## Responsabilités des outils

| Outil | Responsabilité prévue |
|---|---|
| AWS | Hébergement, réseau et stockage |
| Terraform | Gestion du cycle de vie des ressources AWS |
| Ansible | Configuration des serveurs et déploiement |
| Docker | Exécution des services |
| GitHub Actions | Vérifications, construction et déploiement |
| Spring Boot / Angular | API et interface utilisateur |
| EJBCA | Autorités de certification et gestion des certificats |
| SoftHSM | Token PKCS#11 logiciel pour les clés de la CA |

SoftHSM est un simulateur logiciel : il n'offre pas les garanties de protection physique d'un HSM matériel.

## Structure actuelle

- `modules/vpc/main.tf` : ressources réseau.
- `modules/vpc/variables.tf` : paramètres du module.
- `modules/vpc/outputs.tf` : identifiants exposés.
- `modules/vpc/README.md` : documentation du réseau.

Les répertoires de l'application, de la PKI, d'Ansible et des workflows seront ajoutés lors de leur intégration. Un module racine distinct devra appeler le module VPC pour déployer le réseau.

## Module réseau

Le code initial décrit un VPC, des sous-réseaux publics et privés, une Internet Gateway, une Elastic IP, une NAT Gateway et des tables de routage associées.

La région cible du laboratoire est Paris (`eu-west-3`). La NAT Gateway unique est placée dans le premier sous-réseau public. Cette topologie ne fournit pas une NAT indépendante dans chaque zone et ne constitue pas une architecture de production hautement disponible.

## Prérequis

- Terraform et Git installés.
- Compte AWS et permissions adaptées aux ressources prévues.
- AWS CLI configuré sur le poste ; profil local actuel : `terraform`.
- GitHub CLI facultatif pour créer et publier le dépôt depuis le terminal.

Les profils AWS restent locaux et ne doivent pas être copiés dans le dépôt. GitHub Actions utilisera ultérieurement une authentification OIDC dédiée.

## Vérifications locales

Depuis la racine du dépôt :

```powershell
terraform fmt -recursive
terraform fmt -check -recursive
```

Après ajout des exigences de fournisseur au module, une validation isolée est possible :

```powershell
terraform -chdir=modules/vpc init -backend=false
terraform -chdir=modules/vpc validate
```

La validation syntaxique ne garantit ni les permissions AWS, ni la disponibilité des zones, ni la réussite d'un déploiement. Un `terraform plan` sera réalisé depuis le futur module racine.

## Points à corriger avant le premier déploiement

1. Remplacer les zones inexistantes `us-east-3a` et `us-east-3b` par les zones choisies dans `eu-west-3`, après vérification dans le compte.
2. Dans la route privée, utiliser `nat_gateway_id = aws_nat_gateway.main.id`.
3. Vérifier que chaque liste de sous-réseaux ne dépasse pas la longueur de `availability_zones` et qu'au moins un sous-réseau public existe.
4. Enregistrer les fichiers en UTF-8 et corriger les descriptions mal encodées.
5. Déclarer le fournisseur requis, puis ajouter le module racine et examiner son plan.

## Coûts et données sensibles

Un déploiement peut entraîner des frais, notamment pour la NAT Gateway, l'adresse IPv4 publique et les futurs serveurs. Le code seul ne crée rien : examiner le plan et les tarifs avant tout `apply`.

Ne pas publier les états Terraform, plans enregistrés, identifiants AWS, mots de passe, PIN SoftHSM, tokens SoftHSM, clés privées ni sauvegardes de base de données. Le `.gitignore` constitue une aide et ne remplace pas une revue des fichiers avant commit.

Versionner `.terraform.lock.hcl` lorsqu'il est généré, particulièrement pour les configurations racines. Les certificats publics et chaînes de confiance ne sont pas des clés privées ; leur publication éventuelle doit être intentionnelle.

## Feuille de route

- [ ] Corriger, documenter et valider le module VPC.
- [ ] Ajouter une configuration racine de développement.
- [ ] Examiner le plan et déployer le réseau.
- [ ] Ajouter les ressources de calcul nécessaires à l'application.
- [ ] Ajouter les contrôles Terraform dans GitHub Actions.
- [ ] Configurer l'accès AWS OIDC et la gestion de l'état distant avant les déploiements CI.
- [ ] Configurer les serveurs avec Ansible et déployer l'application Docker.
- [ ] Intégrer EJBCA et SoftHSM existants.
- [ ] Mettre en place le mTLS et vérifier réellement le rejet des certificats révoqués.

## Références

- Terraform : https://developer.hashicorp.com/terraform/docs
- Routage AWS Terraform : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
- Régions AWS : https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html

## Licence

Aucune licence de réutilisation n'est attribuée pour le moment. Une licence pourra être choisie avant diffusion plus large.
