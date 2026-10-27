# PKI et application de gestion de rendez-vous sur AWS

Projet pédagogique de Moustapha : infrastructure AWS modulaire avec Terraform, application Spring Boot / Angular et future intégration d'une PKI EJBCA / SoftHSM.

**L'infrastructure du laboratoire est déployée à Paris (`eu-west-3`).** Les tests HTTP via l'ALB, la santé des deux cibles, SSH sur EC2-1 et la connexion MySQL depuis EC2-1 vers RDS ont réussi.

L'application métier, GitHub Actions, Ansible et l'intégration PKI sur AWS restent à réaliser. Les pages Nginx actuelles sont des pages de test.

## État du projet

Résultats documentés à partir des sorties Terraform, AWS CLI, SSH et MySQL partagées les 26 et 27 octobre 2026. Ils décrivent le déploiement observé et ne constituent pas une surveillance continue.

| Composant | État et preuve |
|---|---|
| Configuration racine | Créée ; `terraform validate` réussi |
| VPC | Créé ; état `Available` dans AWS |
| Security | Groupes et règles déployés ; flux ALB/Web, SSH et MySQL testés positivement |
| EC2 | Deux instances `t3.micro` en fonctionnement dans deux zones |
| ALB | Listener HTTP opérationnel ; deux cibles `healthy` |
| Nginx | Installé par `user_data` ; page servie via ALB ; service `active` sur EC2-1 |
| SSH | Connexion réussie sur EC2-1 avec la paire `terraformcloud` |
| RDS | MySQL disponible ; connexion depuis EC2-1 et présence de `moustaphadb` confirmées |
| Application Spring Boot / Angular | Développement existant ; pas encore déployée sur cette infrastructure |
| EJBCA / SoftHSM / Docker | Travail séparé existant ; révocation en cours ; intégration AWS à venir |
| GitHub Actions / Ansible | À mettre en place |
| HTTPS / mTLS | Pas encore configurés pour le trafic Web du laboratoire |

## Objectif et responsabilités

Construire une application de gestion de rendez-vous dont l'infrastructure, la configuration et le déploiement sont reproductibles. La PKI servira à étudier l'émission, le renouvellement et la révocation des certificats, puis l'authentification mutuelle des composants.

| Technologie | Rôle |
|---|---|
| AWS | Réseau, calcul et base de données |
| Terraform | Création et gestion du cycle de vie de l'infrastructure |
| Ansible | Future configuration des serveurs et déploiement |
| GitHub Actions | Futures vérifications et automatisations CI/CD |
| Docker | Future exécution des composants applicatifs |
| Spring Boot / Angular | API métier et interface de gestion des rendez-vous |
| EJBCA | Gestion des autorités et des certificats |
| SoftHSM | Token PKCS#11 logiciel pour les clés de l'autorité |

SoftHSM convient à l'apprentissage et aux tests ; il n'offre pas la protection physique d'un HSM matériel.

## Architecture déployée

| Élément | Configuration observée |
|---|---|
| Région | Paris : `eu-west-3` |
| VPC | `10.0.0.0/16` |
| Sous-réseaux publics | `10.0.1.0/24` en `eu-west-3a` ; `10.0.2.0/24` en `eu-west-3b` |
| Sous-réseaux privés | `10.0.3.0/24` en `eu-west-3a` ; `10.0.4.0/24` en `eu-west-3b` |
| Sortie publique | Internet Gateway |
| Sortie des sous-réseaux privés | NAT Gateway unique dans le premier sous-réseau public |
| EC2 | Deux Ubuntu 24.04 x86_64, type `t3.micro`, dans les sous-réseaux publics |
| ALB | Public, listener HTTP 80, cibles EC2 sur HTTP 80 |
| RDS | MySQL, classe `db.t3.micro`, sous-réseaux privés, accès public désactivé |

Le navigateur contacte l'ALB ; l'ALB contacte Nginx via les adresses privées des instances. Le serveur EC2-1 a également été utilisé comme client MySQL pour tester RDS. Cela ne signifie pas que Nginx ou Spring Boot utilise déjà la base.

Les instances ont une adresse publique pour l'administration SSH du laboratoire. L'ALB n'a pas besoin de ces adresses publiques pour joindre ses cibles.

## Organisation du dépôt

| Chemin | Contenu |
|---|---|
| `main.tf` | Fournisseur AWS et appels des cinq modules ; deux appels du module EC2 |
| `variables.tf` | Entrées de la configuration racine |
| `outputs.tf` ou `output.tf` | Sorties racines ; conserver un seul exemplaire de chaque déclaration |
| `.terraform.lock.hcl` | Version du fournisseur sélectionnée, à versionner |
| `.gitignore` | Exclusions des fichiers locaux et sensibles |
| `modules/vpc/` | VPC, sous-réseaux, passerelles et routage |
| `modules/security/` | Groupes ALB, Web et RDS et règles associées |
| `modules/ec2/` | Instance EC2 et initialisation par `user_data` |
| `modules/rds/` | Groupe de sous-réseaux et instance MySQL |
| `modules/alb/` | ALB, groupe cible, enregistrements et listener |

Chaque module possède ses fichiers de ressources, variables, sorties et son README. `variable.tf` et `variables.tf` sont deux noms acceptés : ne pas dupliquer les déclarations.

Les fichiers locaux `terraform.tfvars`, les états, les plans sauvegardés et le dossier `key/` doivent rester hors du dépôt. Leur exclusion effective dans Git reste à vérifier sur le poste.

## Modules et dépendances

### VPC

Crée le VPC avec DNS activé, deux sous-réseaux publics et deux privés par défaut, une Internet Gateway, une Elastic IP, une NAT Gateway, deux tables de routage et leurs associations.

Sorties : `vpc_id`, `public_subnet_ids`, `private_subnet_ids`.

La route publique utilise `gateway_id` vers l'Internet Gateway. La route privée utilise `nat_gateway_id`. Les listes de CIDR et de zones doivent être cohérentes. La NAT unique ne fournit pas de redondance par zone.

### Security

| Destination | Source | Entrée autorisée |
|---|---|---|
| ALB | Internet IPv4 | TCP 80 et 443 |
| Web | Groupe ALB | TCP 80 |
| Web | IPv4 publique du poste autorisée en `/32` | TCP 22 |
| RDS | Groupe Web | TCP 3306 |

L'ALB peut sortir vers Web sur TCP 80. Les groupes Web et RDS ont des sorties IPv4 générales dans cette version du laboratoire.

Les règles utilisent `aws_vpc_security_group_ingress_rule` et `aws_vpc_security_group_egress_rule`. Ne pas les mélanger avec des règles intégrées aux mêmes groupes.

Sorties : `aws_sg_id`, `rds_sg_id`, `alb_sg_id`.

Les tests positifs réalisés ne démontrent pas le rejet de tous les flux interdits. Le port 443 autorisé ne crée pas de listener HTTPS.

### EC2

Le module est appelé deux fois : `ec2-1` et `ec2-2`. Chaque appel reçoit une AMI, un type d'instance, un sous-réseau, les groupes de sécurité, une paire SSH et un script `user_data`.

Configuration utilisée : AMI `ami-001b955040bc46321`, Ubuntu 24.04 x86_64 à Paris, type `t3.micro`, paire `terraformcloud`, utilisateur SSH `ubuntu`.

Le script installe Nginx et écrit une page identifiant l'instance. Cette initialisation a été utilisée pour les tests ; l'automatisation Ansible reste à construire. La modification de `user_data` ne garantit pas sa réexécution sur une instance existante.

Sorties : `ec2_public_ip`, `ec2_private_ip`, `public_dns`, `private_dns`, `instance_id`, `ssh_command`.

### RDS

Crée une instance MySQL dans un groupe de sous-réseaux privés couvrant deux zones. La configuration est Single-AZ ; cela ne crée pas de réplique de secours.

| Paramètre | Valeur du déploiement |
|---|---|
| Famille moteur configurée | MySQL `8.0` |
| Version observée dans le client | `8.0.46-eol-2-rds.20260908` |
| Classe | `db.t3.micro` |
| Base initiale | `moustaphadb` |
| Stockage | 20 Gio `gp3`, chiffré selon le plan appliqué |
| Accès public | Désactivé |
| Sauvegardes automatisées | Désactivées |
| Snapshot final / protection contre la suppression | Désactivés |

Le cycle de support du moteur et les éventuels frais de support étendu restent à examiner. Cette configuration est réservée aux données jetables du laboratoire.

Sorties : `rds_endpoint`, `rds_instance_id`, `rds_address`, `rds_port`.

Le mot de passe n'est jamais documenté ici. Avec l'argument Terraform `password`, il reste présent dans l'état. Un compte applicatif limité reste à créer.

### ALB

Crée un ALB public réparti dans deux zones, un groupe cible HTTP 80, deux enregistrements EC2 et un listener HTTP 80.

Contrôle de santé : chemin `/`, codes `200-299`, intervalle 30 secondes, timeout 5 secondes et seuils de 2. Délai de drainage : 300 secondes.

Sorties : `alb_dns`, `url_alb`, `zone_id`, `alb_arn`, `target_group_arn`. La sortie `zone_id` désigne la zone AWS du load balancer pour une cible Alias, pas la zone DNS de votre domaine.

Aucun certificat, listener HTTPS ou mTLS n'est encore configuré. Si toutes les cibles deviennent défaillantes, l'ALB peut continuer à leur transmettre le trafic : les health checks ne sont pas un contrôle de sécurité.

## Déploiement réussi : étapes et résultats

### 1. Préparer l'identité AWS et la région

Le profil local `terraform` utilise les identifiants temporaires du profil `moustapha-login`. L'identité vérifiée est l'utilisateur IAM `terraform-user-moustapha`.

```powershell
aws login --profile moustapha-login --region eu-west-3
aws sts get-caller-identity --profile terraform
```

La première commande sert à créer ou renouveler la session si nécessaire. Sélectionner l'utilisateur IAM du projet.

Les autorisations administrateur ont été attachées au groupe du laboratoire pour ce déploiement. Elles devront être remplacées par des droits adaptés, notamment pour le futur rôle GitHub Actions OIDC.

### 2. Initialiser et valider

Depuis la racine du projet :

```powershell
terraform fmt -recursive
terraform init
terraform validate
```

Résultats observés :

```text
Terraform has been successfully initialized!
Success! The configuration is valid.
```

Le fournisseur installé est `hashicorp/aws` v5.100.0, sélectionné par la contrainte `~> 5.0`. La validation a été réalisée depuis la racine avec tous les modules appelés ; aucun compte rendu séparé de validation isolée de chaque module n'est revendiqué.

### 3. Examiner le plan et corriger SSH

Le premier plan complet proposait 33 créations sans règle SSH. La commande `terraform console`, suivie de `var.allowed_ssh_cidr`, retournait `tolist([])`.

Après transmission de la variable au module Security et ajout de l'IPv4 publique réelle du poste en `/32` dans le fichier local de valeurs :

```text
Plan: 34 to add, 0 to change, 0 to destroy.
```

Une ressource `web_ssh` sur TCP 22 apparaissait alors. L'adresse source autorisée doit être mise à jour si la connexion Internet ou le VPN change.

### 4. Appliquer et reprendre après l'erreur EC2

```powershell
terraform apply
```

Le premier apply a créé notamment le réseau, la NAT, l'ALB et RDS, mais les deux instances `t2.micro` ont été refusées par AWS avec le message :

```text
The specified instance type is not eligible for Free Tier.
```

Le déploiement a donc été partiel. Les créations réussies n'ont pas été annulées, et le fichier d'état a été conservé.

Les types proposés par AWS ont été consultés :

```powershell
aws ec2 describe-instance-types --region eu-west-3 --profile terraform --filters "Name=free-tier-eligible,Values=true" "Name=processor-info.supported-architecture,Values=x86_64" --query "InstanceTypes[].InstanceType" --output table
```

`t3.micro` figurait dans le résultat et a remplacé `t2.micro` dans les valeurs locales. Cette éligibilité observée n'est pas une garantie de gratuité de l'infrastructure.

La reprise a été effectuée sans supprimer les ressources existantes ni l'état :

```powershell
terraform validate
terraform plan
terraform apply
```

Résultat du plan de reprise :

```text
Plan: 4 to add, 0 to change, 0 to destroy.
```

Résultat final :

```text
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

Ces quatre créations correspondent aux deux instances EC2 et à leurs deux enregistrements ALB. Ce nombre ne représente pas la totalité de l'infrastructure créée au cours des deux exécutions.

### 5. Vérifier les ressources et les sorties

```powershell
terraform output
```

Les captures AWS ont confirmé le VPC `Available`, les deux EC2 `t3.micro` en fonctionnement avec leurs contrôles de statut réussis, et RDS `Disponible`.

| Ressource | Identifiant ou adresse observée |
|---|---|
| EC2-1 | `i-06080da267470e3af`, zone `eu-west-3a` |
| EC2-2 | `i-049fdba5e7f0eb42b`, zone `eu-west-3b` |
| IPv4 privée EC2-1 | `10.0.1.197` |
| IPv4 privée EC2-2 | `10.0.2.79` |
| URL ALB | `http://alb-moustapha-dev-1633483388.eu-west-3.elb.amazonaws.com` |
| Endpoint RDS | `rds-moustapha-dev.cj6oo4qew5ix.eu-west-3.rds.amazonaws.com:3306` |

Ces identifiants peuvent changer lors d'une recréation. Utiliser les sorties Terraform pour obtenir les valeurs actuelles. Les IPv4 publiques EC2 peuvent aussi changer après arrêt et démarrage.

### 6. Tester HTTP via l'ALB

Ouvrir la sortie `load_balancer_url`, ou depuis PowerShell :

```powershell
$albUrl = terraform output -raw load_balancer_url
Invoke-WebRequest -Uri $albUrl -UseBasicParsing
```

Le test navigateur a affiché :

```text
Bienvenue sur l'instance EC2-2-dev
```

Cela confirme le chemin navigateur vers ALB vers Nginx sur EC2-2. Une actualisation ne garantit pas une alternance stricte entre les serveurs.

### 7. Vérifier les deux cibles ALB

Commande utilisée pour ce déploiement :

```powershell
$targetGroupArn = "arn:aws:elasticloadbalancing:eu-west-3:231644789895:targetgroup/tg-moustapha-dev/5409a073821009d3"
aws elbv2 describe-target-health --target-group-arn $targetGroupArn --region eu-west-3 --profile terraform --query "TargetHealthDescriptions[].{Instance:Target.Id,Etat:TargetHealth.State}" --output table
```

Résultat observé :

| Instance | État |
|---|---|
| `i-06080da267470e3af` | `healthy` |
| `i-049fdba5e7f0eb42b` | `healthy` |

L'ALB réussissait donc ses contrôles HTTP sur les deux instances au moment du test.

### 8. Corriger les permissions Windows et tester SSH

Le premier accès SSH a échoué avec `UNPROTECTED PRIVATE KEY FILE`. OpenSSH refusait une clé lisible par des groupes Windows trop larges.

Les permissions du fichier privé ont été corrigées depuis PowerShell :

```powershell
$keyPath = (Resolve-Path ".\key\terraformcloud.pem").Path
$monCompte = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
icacls "$keyPath" /grant:r "${monCompte}:(R)"
icacls "$keyPath" /inheritance:r
icacls "$keyPath" /remove:g "*S-1-5-32-545" "*S-1-5-11"
icacls "$keyPath"
```

Ces commandes concernent le fichier privé local uniquement. Arrêter la procédure si une commande retourne un refus d'accès. Ne jamais publier son contenu.

La connexion suivante a réussi depuis la racine du projet :

```powershell
ssh -i ".\key\terraformcloud.pem" ubuntu@13.39.235.150
```

Résultat : ouverture d'une session Ubuntu sur EC2-1 (`10.0.1.197`). Sur cette instance :

```bash
systemctl is-active nginx
```

Résultat :

```text
active
```

Le test SSH sur EC2-2 n'a pas encore été documenté.

### 9. Tester EC2-1 vers RDS MySQL

Dans la session Ubuntu sur EC2-1, installer le client MySQL :

```bash
sudo apt-get update
sudo apt-get install -y mysql-client
```

Se connecter à l'endpoint sans inscrire le mot de passe dans la commande :

```bash
mysql \
  --host=rds-moustapha-dev.cj6oo4qew5ix.eu-west-3.rds.amazonaws.com \
  --port=3306 \
  --user=admin \
  --password \
  --ssl-mode=REQUIRED
```

Saisir le mot de passe localement à l'invite. La connexion a réussi. Dans MySQL :

```sql
SHOW DATABASES;
```

La sortie contenait :

```text
information_schema
moustaphadb
mysql
performance_schema
sys
```

Ce test confirme le chemin réseau EC2-1 vers RDS, l'authentification, la base initiale et une connexion exigeant TLS. `--ssl-mode=REQUIRED` impose le chiffrement mais ne vérifie pas à lui seul l'identité du serveur comme `VERIFY_IDENTITY` avec une CA de confiance. Ce n'est pas un test mTLS EJBCA.

Quitter les sessions :

```sql
exit;
```

```bash
exit
```

### Bilan des tests

| Test | Résultat | Limite |
|---|---|---|
| Validation Terraform racine | Réussie | Ne constitue pas un contrôle de production |
| Déploiement | Réussi après reprise | Ressources payantes actives |
| Page via ALB | Réussie sur EC2-2 | Page Nginx, pas l'application métier |
| Santé ALB | Deux cibles `healthy` | État observé au moment du test |
| SSH | Réussi sur EC2-1 | EC2-2 non testé en SSH |
| Service Nginx EC2-1 | `active` | Aucun test de panne réalisé |
| EC2-1 vers RDS | Connexion réussie | Utilisation du compte administrateur |
| Base `moustaphadb` | Présente | Aucun schéma métier testé |
| Spring Boot vers RDS | Non testé | Application non déployée |
| HTTPS, mTLS et révocation | Non configurés sur AWS | Intégration PKI à venir |

## Configuration et exploitation

### Paramètres racines

`variables.tf` déclare les entrées et leurs valeurs par défaut. Le fichier local `terraform.tfvars` peut les remplacer. Les valeurs retenues pour le déploiement sont Paris, `t3.micro`, l'AMI Ubuntu vérifiée et la paire `terraformcloud`.

Le mot de passe RDS ne doit avoir aucune valeur par défaut versionnée. La suppression de sa valeur locale n'effectue pas une rotation ; pour examiner un plan sans modification involontaire, fournir le secret actuellement déployé. Une rotation explicite reste à réaliser puisque le mot de passe initial a été partagé.

### Contrôles avant une prochaine modification

```powershell
terraform fmt -recursive
terraform validate
terraform plan
```

Examiner les changements et les éventuels remplacements avant tout apply. Aucun résultat de plan sans changement après la dernière édition des commentaires n'a encore été fourni.

Conserver `terraform.tfstate` et ses sauvegardes hors Git : ils relient la configuration aux ressources existantes. Le backend distant et le verrouillage pour le travail CI restent à préparer.

### Publication Git

Avant le commit :

```powershell
git status
git ls-files key/
git ls-files '*.tfvars' '*.tfstate' '*.tfstate.*'
```

Inspecter les résultats : aucune clé privée, aucun fichier de valeurs secret ni état ne doit être suivi. `.gitignore` ne retire pas les fichiers déjà suivis et ne nettoie pas l'historique.

Versionner `.terraform.lock.hcl` ; ignorer le dossier `.terraform/`. Préparer un `terraform.tfvars.example` sans secret pour les utilisateurs du dépôt.

## Difficultés rencontrées et solutions

| Problème | Cause | Solution appliquée |
|---|---|---|
| Région `us-east-3` invalide | Mauvaise valeur régionale | Utiliser `eu-west-3` |
| `Unexpected attribute: vpc_id` dans RDS | Entrée absente du module RDS corrigé | Retirer cet argument de son appel |
| Sorties non reconnues | Noms racines différents des sorties enfants | Utiliser `rds_endpoint`, `ec2_public_ip`, `ec2_private_ip` ; ajouter `private_dns` |
| Absence de règle SSH | Liste `allowed_ssh_cidr` vide | Fournir une IPv4 publique réelle en `/32` et transmettre la variable |
| Paire SSH introuvable à Paris | Paire initialement créée à Stockholm | Créer et vérifier une paire à Paris |
| Session AWS expirée | Identifiants temporaires expirés | Renouveler avec `aws login` |
| EC2 `t2.micro` refusées | Type non éligible pour l'offre du compte au moment du test | Consulter les types éligibles et sélectionner `t3.micro` |
| Clé privée ignorée par OpenSSH | Permissions Windows trop ouvertes | Restreindre les permissions du fichier |

## Coûts et limites du laboratoire

Les ressources créées peuvent consommer des crédits et entraîner des frais : EC2, volumes, IPv4 publiques, RDS, NAT Gateway, ALB et transferts de données. Le label Free Tier d'un type d'instance ne signifie pas que tout le projet est gratuit.

Le laboratoire conserve actuellement une NAT unique, une base Single-AZ sans sauvegarde automatique ni snapshot final, et un accès Web HTTP. Il n'est pas prêt pour des données réelles ou un service de production.

Prévoir une stratégie de fin de laboratoire. Arrêter les EC2 ne supprime pas les coûts des autres services. Toute destruction doit être volontaire, précédée de l'examen du plan de destruction et de la sauvegarde des données à conserver.

## Feuille de route

- [x] Créer le dépôt et documenter les modules.
- [x] Relier VPC, Security, RDS, deux EC2 et ALB dans la racine.
- [x] Initialiser et valider la configuration racine.
- [x] Corriger la région et les sorties des modules.
- [x] Créer la règle SSH limitée au poste.
- [x] Remplacer `t2.micro` par `t3.micro` après vérification AWS.
- [x] Terminer le déploiement après reprise.
- [x] Vérifier le VPC, les EC2 et RDS dans la console.
- [x] Tester la page HTTP via l'ALB.
- [x] Vérifier les deux cibles `healthy`.
- [x] Corriger les permissions de la clé et tester SSH sur EC2-1.
- [x] Vérifier Nginx actif sur EC2-1.
- [x] Tester MySQL depuis EC2-1 et vérifier `moustaphadb`.
- [ ] Tester SSH sur EC2-2.
- [ ] Vérifier l'absence de secrets, clés et états dans Git et son historique.
- [ ] Effectuer la rotation du mot de passe RDS partagé.
- [ ] Créer un compte MySQL applicatif limité.
- [ ] Examiner le support du moteur MySQL et les coûts.
- [ ] Vérifier un plan sans changement après les dernières modifications.
- [ ] Ajouter les vérifications Terraform dans GitHub Actions.
- [ ] Préparer l'état distant, son verrouillage et le rôle AWS OIDC de CI.
- [ ] Automatiser la configuration avec Ansible.
- [ ] Déployer Spring Boot / Angular et les conteneurs Docker.
- [ ] Exécuter les migrations métier et tester l'application avec RDS.
- [ ] Définir HTTPS et l'architecture de chiffrement interne.
- [ ] Intégrer EJBCA et SoftHSM.
- [ ] Configurer mTLS et vérifier le rejet effectif d'un certificat révoqué.
- [ ] Tester renouvellement, sauvegarde et restauration.

## Références

- [Dépôt du projet](https://github.com/kamoustaph/pki-aws-terraform-rendezvous)
- [Terraform](https://developer.hashicorp.com/terraform/docs)
- [Fournisseur AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Application Load Balancers](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html)
- [RDS dans un VPC](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)
- [Paires de clés EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)

## Licence

Aucune licence de réutilisation n'est attribuée pour le moment.
