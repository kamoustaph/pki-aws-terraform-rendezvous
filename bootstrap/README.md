# Infrastructure AWS avec Terraform et GitHub Actions

Projet pédagogique de Moustapha : déploiement d’une infrastructure AWS modulaire, organisation des environnements et automatisation avec GitHub Actions.

L’infrastructure constitue la base du projet de gestion de rendez-vous Spring Boot / Angular et de la future intégration PKI EJBCA / SoftHSM. Ces composants applicatifs ne sont pas déployés par la configuration présentée ici.

## 1. État du projet

Les opérations suivantes ont été réalisées :

- Déploiement de l’infrastructure AWS dans la région Paris (`eu-west-3`).
- Installation automatique de Nginx sur deux instances EC2.
- Accès HTTP via l’Application Load Balancer.
- Vérification de la santé des deux cibles de l’ALB.
- Connexion SSH à une instance EC2.
- Connexion MySQL depuis EC2 vers RDS.
- Création du bucket S3 destiné aux states Terraform.
- Configuration des backends par environnement.
- Test de déploiement et de destruction depuis GitHub Actions.

Le dernier journal de destruction examiné indique :

```text
Destroy complete! Resources: 34 destroyed.
```

La vérification des snapshots RDS manuels n’a retourné aucun résultat après ce nettoyage.

Le bucket S3 du bootstrap est conservé pour les prochains déploiements.

## 2. Architecture

L’environnement comprend :

- Un VPC.
- Deux sous-réseaux publics et deux sous-réseaux privés.
- Une Internet Gateway.
- Une NAT Gateway et son Elastic IP.
- Des tables de routage.
- Des groupes de sécurité.
- Deux instances EC2 avec Nginx.
- Un Application Load Balancer et son groupe cible.
- Une base RDS MySQL dans les sous-réseaux privés.

Le stockage du state est séparé de cette infrastructure :

- `bootstrap` crée le bucket S3.
- Chaque environnement utilise son propre fichier state dans ce bucket.

## 3. Organisation du dépôt

| Chemin | Contenu |
|---|---|
| `bootstrap/main.tf` | Création et protection du bucket S3 |
| `bootstrap/outputs.tf` | Nom du bucket créé |
| `modules/vpc/` | Réseau et routage |
| `modules/security/` | Groupes et règles de sécurité |
| `modules/ec2/` | Instances EC2 |
| `modules/rds/` | Base MySQL RDS |
| `modules/alb/` | Load balancer et groupe cible |
| `environments/dev/` | Configuration de développement |
| `environments/staging/` | Configuration de staging |
| `environments/prod/` | Configuration de production |
| `.github/workflows/terraform.yml` | Pipeline GitHub Actions |

Les fichiers Terraform encore présents à la racine correspondent à la configuration historique. Les commandes décrites ci-dessous utilisent les dossiers `environments/`.

Chaque dossier d’environnement contient notamment :

- `main.tf`
- `variables.tf`
- `outputs.tf`
- `terraform.tfvars`
- `backend.tf`

## 4. Prérequis

- Terraform `1.17.0`, version utilisée pour les tests.
- AWS CLI configurée.
- Git.
- Un compte AWS et les permissions nécessaires.
- Une paire de clés EC2 existante dans la région ciblée.
- Un accès au dépôt GitHub pour exécuter le pipeline.

Vérifier les outils et l’identité AWS :

```powershell
terraform version
aws --version
git --version
aws sts get-caller-identity
```

La région utilisée est :

```text
eu-west-3
```

La version Terraform configurée dans le pipeline doit également être compatible avec le verrouillage natif S3 :

```yaml
env:
  TF_VERSION: "1.17.0"
  AWS_REGION: eu-west-3
```

## 5. Pourquoi conserver le state dans S3 ?

Le fichier `terraform.tfstate` associe les ressources du code à leurs identifiants réels dans AWS.

Il permet à Terraform de déterminer :

- Les ressources déjà créées.
- Les modifications nécessaires.
- Les ressources à supprimer.

Un runner GitHub Actions est temporaire. Un state uniquement local n’est pas automatiquement transmis à l’exécution suivante.

Sans state partagé, un nouvel `apply` peut tenter de recréer une infrastructure existante et provoquer des erreurs :

```text
Load Balancer already exists
Target Group already exists
DBSubnetGroupAlreadyExists
```

Le backend S3 conserve le state entre les exécutions locales et GitHub Actions.

Ajouter un backend distant ne permet pas de retrouver automatiquement les ressources créées auparavant sans state. Il faut alors récupérer un ancien state, importer les ressources ou effectuer un nettoyage contrôlé.

## 6. Bootstrap du bucket S3

### Configuration

Le dossier `bootstrap` crée quatre ressources Terraform :

| Ressource | Rôle |
|---|---|
| `aws_s3_bucket` | Stockage des states |
| `aws_s3_bucket_versioning` | Conservation des versions précédentes |
| `aws_s3_bucket_server_side_encryption_configuration` | Chiffrement SSE-S3 |
| `aws_s3_bucket_public_access_block` | Blocage des accès publics |

Nom du bucket utilisé :

```text
terraform-bucket-moustapha-2026
```

Le bootstrap utilise le provider AWS fixé à `5.0.0`. La version du provider AWS est indépendante de la version du logiciel Terraform.

### Création initiale

À exécuter une seule fois pour créer le stockage partagé :

```powershell
cd C:\terraform_modules_moustapha\bootstrap

terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Examiner le plan, puis saisir `yes` pour confirmer.

Résultat obtenu lors du test :

```text
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

Vérifier les ressources gérées :

```powershell
terraform state list
```

Résultat attendu :

```text
aws_s3_bucket.terraform_bucket
aws_s3_bucket_public_access_block.terraform_state
aws_s3_bucket_server_side_encryption_configuration.terraform_state
aws_s3_bucket_versioning.terraform_state
```

### State du bootstrap

Avec la configuration actuelle, le state du bootstrap reste local :

```text
bootstrap/terraform.tfstate
```

Conserver une sauvegarde sécurisée de ce fichier et ne pas le publier dans Git.

Ne pas exécuter `terraform destroy` dans `bootstrap` pour nettoyer un environnement : ce dossier gère le bucket partagé.

## 7. Backend S3 des environnements

### Développement

Fichier `environments/dev/backend.tf` :

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-bucket-moustapha-2026"
    key    = "dev/terraform.tfstate"
    region = "eu-west-3"

    encrypt      = true
    use_lockfile = true
  }
}
```

### Staging et production

Les fichiers utilisent le même bucket, avec des clés distinctes :

| Environnement | Clé S3 |
|---|---|
| dev | `dev/terraform.tfstate` |
| staging | `staging/terraform.tfstate` |
| prod | `prod/terraform.tfstate` |

Les chemins ci-dessus correspondent au workspace `default`.

Chaque dossier d’environnement utilise son workspace `default`. Cette organisation ne doit pas être confondue avec les anciens workspaces créés à la racine.

### Verrouillage

`use_lockfile = true` active le verrouillage natif S3.

Pendant une opération nécessitant un verrou, Terraform utilise un objet tel que :

```text
dev/terraform.tfstate.tflock
```

Ce mécanisme empêche deux opérations de modifier simultanément le même state.

Il nécessite Terraform 1.10 ou supérieur. Aucune table DynamoDB n’est utilisée dans cette configuration.

Le verrouillage Terraform est distinct de la fonctionnalité S3 Object Lock.

### Permissions

Les identifiants utilisés localement et dans GitHub Actions doivent pouvoir :

- Lister les préfixes nécessaires du bucket.
- Lire et écrire le state de l’environnement.
- Lire, créer et supprimer son fichier de verrouillage.

Le chiffrement ne remplace pas les permissions IAM.

## 8. Initialiser un environnement

Pour `dev` :

```powershell
cd C:\terraform_modules_moustapha\environments\dev

terraform init
terraform workspace show
terraform state list
```

Le message attendu pendant l’initialisation est :

```text
Successfully configured the backend "s3"!
```

Le workspace attendu est :

```text
default
```

Avant le premier déploiement, aucun objet n’est enregistré dans le state. Une initialisation réussie ne signifie pas que l’infrastructure a été créée.

Si Terraform propose une migration d’un state existant, vérifier son origine avant de confirmer.

Pour les autres environnements, exécuter les mêmes commandes dans leurs dossiers respectifs.

## 9. Déployer depuis PowerShell

Exemple pour `dev` :

```powershell
cd C:\terraform_modules_moustapha\environments\dev

terraform init
terraform fmt
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Le fichier `terraform.tfvars` de ce dossier est chargé automatiquement.

Un fichier nommé `dev.tfvars` n’est pas chargé automatiquement : il faut utiliser `-var-file` lorsqu’il est nécessaire.

Ne pas publier le plan sauvegardé : il peut contenir des données sensibles.

Afficher les résultats :

```powershell
terraform output
terraform state list
```

Répéter l’opération dans `staging` ou `prod` uniquement lorsque leur déploiement est souhaité.

## 10. Variables et secrets

Les paramètres d’un environnement incluent notamment :

- Région AWS.
- AMI.
- Type d’instance.
- Nom de la paire de clés.
- Nom du projet.
- Environnement.
- Paramètres RDS.
- Plages IPv4 autorisées pour SSH.

Pour autoriser une seule IPv4 publique en SSH :

```hcl
allowed_ssh_cidr = ["VOTRE_IPV4_PUBLIQUE/32"]
```

Ne pas publier les clés AWS, les clés SSH privées ou les mots de passe.

Pour fournir localement le mot de passe RDS par variable d’environnement :

```powershell
$env:TF_VAR_db_password = Read-Host "Mot de passe RDS" -MaskInput
```

`-MaskInput` nécessite PowerShell 7.

Le mot de passe doit être absent des fichiers de variables chargés s’il doit provenir de cette variable d’environnement, car ces fichiers peuvent avoir priorité.

Dans GitHub Actions, utiliser le secret `DB_PASSWORD` :

```yaml
env:
  TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
```

Le state et les plans peuvent contenir le mot de passe même si son affichage est masqué.

## 11. Pipeline GitHub Actions

### Pull requests

Une pull request vers `main` lance les plans pour :

- `dev`
- `staging`
- `prod`

Le job de diagnostic affiche notamment :

- Le type d’événement.
- La branche.
- Le commit.
- Les choix du formulaire manuel.
- Le résultat des conditions des jobs.

### Exécution manuelle

Depuis GitHub :

1. Ouvrir **Actions**.
2. Sélectionner **Terraform CI/CD**.
3. Cliquer sur **Run workflow**.
4. Sélectionner la branche contenant la configuration souhaitée.
5. Choisir l’action et l’environnement.
6. Confirmer le lancement.

Le job `apply` doit lire l’entrée du formulaire :

```yaml
if: github.event_name == 'workflow_dispatch' && github.event.inputs.action == 'apply'
```

Pour `destroy` :

```yaml
if: github.event_name == 'workflow_dispatch' && github.event.inputs.action == 'destroy'
```

Le choix manuel `plan` nécessite un job ou une condition qui traite explicitement cette action. Déclarer une option dans le formulaire ne crée pas automatiquement le job correspondant.

Les exécutions manuelles doivent utiliser un backend correctement initialisé et la même clé S3 pour retrouver le state de l’environnement.

### Secrets GitHub

Configurer dans les paramètres Actions du dépôt :

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `DB_PASSWORD`

Ne jamais afficher ces valeurs dans les logs.

### Lire les résultats

- `Queued` : le job attend son démarrage.
- `Skipped` : sa condition n’est pas satisfaite.
- `Failure` : une étape a échoué.
- `Success` : le job a terminé selon ses règles de gestion des erreurs.

Avec `continue-on-error: true`, une erreur peut être masquée par un statut global vert. Examiner les logs et les résultats des étapes.

L’option `-detailed-exitcode` concerne `terraform plan` :

| Code | Signification |
|---|---|
| 0 | Plan réussi, aucun changement |
| 1 | Erreur |
| 2 | Plan réussi, changements prévus |

Ne pas utiliser cette option avec `terraform apply`.

Après modification du workflow, lancer une nouvelle exécution pour tester le nouveau commit. Relancer une ancienne exécution conserve son commit d’origine.

## 12. Vérifications après déploiement

Afficher les sorties :

```powershell
terraform output
```

### HTTP

Ouvrir la valeur de :

```text
load_balancer_url
```

La page Nginx permet d’identifier l’instance qui répond.

### SSH

Utiliser la commande fournie dans les sorties EC2.

Une fois connecté :

```bash
systemctl is-active nginx
```

Résultat attendu :

```text
active
```

### RDS MySQL

Depuis une instance autorisée par le groupe de sécurité RDS :

```bash
mysql \
  --host=VOTRE_ENDPOINT_RDS_SANS_PORT \
  --port=3306 \
  --user=VOTRE_UTILISATEUR \
  --password \
  --ssl-mode=REQUIRED
```

Puis :

```sql
SHOW DATABASES;
```

Ne pas transmettre le mot de passe en clair dans la commande.

## 13. Détruire un environnement

Exemple pour `dev` :

```powershell
cd C:\terraform_modules_moustapha\environments\dev

terraform init
terraform state list
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

Examiner le plan de destruction avant son application.

Le test réalisé a retourné :

```text
Destroy complete! Resources: 34 destroyed.
```

Le bucket du bootstrap reste disponible.

Un résultat `0 destroyed` ne prouve pas que le compte AWS est vide : il faut vérifier que le bon environnement et le bon state ont été utilisés.

### Snapshots RDS

Selon la configuration du module RDS, un snapshot final peut être conservé.

Vérification :

```powershell
aws rds describe-db-snapshots --region eu-west-3 --snapshot-type manual --query "DBSnapshots[].{Snapshot:DBSnapshotIdentifier,Base:DBInstanceIdentifier,Etat:Status}" --output table
```

Ne supprimer un snapshot qu’après avoir vérifié que sa sauvegarde n’est plus nécessaire.

## 14. Fichiers à conserver hors de Git

Exemples de règles `.gitignore` :

```gitignore
# Cache Terraform.
**/.terraform/*

# States et sauvegardes de state.
*.tfstate
*.tfstate.*

# Plans sauvegardés.
*.tfplan
*.plan
tfplan

# Journaux locaux.
crash.log
crash.*.log

# Secrets.
.env
.env.*
!.env.example
.aws/
*.pem
*.key
secrets/
backups/
```

Les fichiers `.terraform.lock.hcl` peuvent être versionnés pour conserver les versions des providers.

Les fichiers `.tfvars` ne doivent être publiés que s’ils ne contiennent aucun secret.

## 15. Dépannage

| Message | Cause ou vérification |
|---|---|
| `touch` non reconnu | Utiliser `New-Item` sous PowerShell |
| `Reference to undeclared resource` | Vérifier le nom exact de la ressource référencée |
| `failed to get shared config profile` | Un profil local est imposé dans une configuration utilisée par GitHub |
| `already exists` | Vérifier le backend et le state avant tout nouvel apply |
| `-detailed-exitcode: command not found` | Option isolée dans le script shell |
| Tous les jobs sont ignorés | Examiner leurs conditions `if:` |
| `No state file was found` | Vérifier le dossier, le backend et l’existence d’un state |
| `Error acquiring the state lock` | Vérifier qu’aucune autre opération n’utilise le même state |

Ne pas supprimer manuellement un verrou sans avoir confirmé qu’aucune opération Terraform n’est encore active.

## 16. Gestion des coûts

Les ressources du laboratoire peuvent générer des frais, notamment :

- EC2 et volumes EBS.
- RDS et snapshots.
- ALB.
- NAT Gateway.
- Adresses IPv4 publiques.
- Stockage et requêtes S3.

La destruction d’un environnement supprime les ressources présentes dans son state. Elle ne supprime pas automatiquement les ressources étrangères à ce state.

Après un test, vérifier la réussite du destroy et les éventuelles sauvegardes conservées.

## 17. Évolutions prévues

- Intégration de l’application Spring Boot / Angular.
- Intégration de la PKI EJBCA / SoftHSM.
- Authentification GitHub Actions vers AWS par OIDC.
- Affinement des permissions IAM par environnement.
- Sauvegarde durable du state du bootstrap.
- Documentation des tests applicatifs et PKI.