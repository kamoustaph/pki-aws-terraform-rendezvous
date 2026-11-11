# Mise en place du HTTPS de Yoon : compte rendu (5 au 11 novembre 2026)

Ce document retrace **ce qui a été fait**, dans l'ordre, avec les résultats obtenus, les erreurs rencontrées et
leurs corrections. La procédure à suivre à l'avenir est dans [`PKI-HTTPS-YOON.md`](PKI-HTTPS-YOON.md) ; le rapport
illustré par les captures d'écran est [`Yoon-rapport-deploiement-AWS-PKI-EJBCA.pdf`](Yoon-rapport-deploiement-AWS-PKI-EJBCA.pdf).

## Résultat

| Vérification | Résultat |
|---|---|
| URL | `https://alb-moustapha-dev-2014044716.eu-west-3.elb.amazonaws.com` |
| Port 80 | `HTTP/1.1 301 Moved Permanently`, `Location: https://…:443/` |
| Protocole | TLS 1.3, `TLS_AES_128_GCM_SHA256` (Firefox) |
| Chaîne | `Lab-RootCA-SoftHSM2` → `Lab-IntermediateCA-SoftHSM2` → nom de l'ALB ; Firefox : « Vérifiée par : PKI LAB » |
| Certificat | RSA 3072, n° `5D0C16B5F3D37AC6DD332CE7047BDE1B79296AAC`, du 10/11/2026 au 12/12/2027 |
| Extensions | SAN = nom de l'ALB ; Key Usage critique ; EKU Server Authentication ; CDP et AIA vers S3 |
| Révocation | `openssl verify -crl_check` : `alb.crt: OK` ; certificat enregistré dans EJBCA, statut *Active* |
| Appareils | Root installée sur Windows (empreinte vérifiée), reprise par Firefox ; Android |
| Test métier | scanner caméra sur Android en HTTPS : billet embarqué, puis refusé « Billet déjà utilisé » |

## Chronologie

| Date | Étape | Résultat |
|---|---|---|
| 05/11 | PR #15 : bucket des CRL, module ALB avec `certificate_arn`, documentation | plans sans changement ; fusionnée |
| 05/11 | `terraform apply` du bootstrap | `5 added, 0 changed, 0 destroyed` |
| 05/11 | Réglages des CA dans EJBCA, CRL n° 2 puis n° 3 | CRL 30 j (Root) et 7 j (Intermediate) |
| 06/11 | Copie Windows ↔ VM (dossier partagé), publication sur S3 | 4 fichiers publiés, identiques à EJBCA |
| 06/11 | Incident de la VM (écran noir, `fsck`, kernel panic) | réparée sans perte |
| 07/11 | Profils `TLS-SERVER-YOON` et `EE-TLS-YOON` ; CLI AWS dans la VM | profils enregistrés (corrigés ensuite) |
| 07/11 | `dev` absent → recréé ; clé 2048 et CSR | ALB `…1842800432…` |
| 10/11 | `dev` de nouveau absent → recréé ; CRL n° 4 par la CLI EJBCA | ALB `…2014044716…` (actuel) |
| 10/11 | Clé RSA 3072, émission par la CLI EJBCA, import ACM | ARN `…5c6f0b7d-92c0-4568-87f5-8c4fb01fa4ce` |
| 10/11 | PR #16 : `certificate_arn` dans `environments/dev/terraform.tfvars` ; apply | `1 added, 1 changed, 0 destroyed` ; HTTPS actif |
| 10/11 | Correction du profil, 2ᵉ puis 3ᵉ émission, réimport sur le même ARN | certificat conforme en service |
| 10–11/11 | Root sur Windows et Android, test du scanner | réussi |

## 1. Infrastructure (PR #15, bootstrap)

```powershell
cd C:\terraform_modules_moustapha\bootstrap
terraform plan      # Plan: 5 to add, 0 to change, 0 to destroy
terraform apply     # Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

Contrôles : blocage public `BlockPublicAcls=true`, `BlockPublicPolicy=false` ; racine du bucket en **403**.
L'état du bootstrap a été sauvegardé dans `C:\sauvegarde-avant-etape4\` (le dossier devait d'abord être créé).

## 2. EJBCA

### État de départ

| Constat | Conséquence |
|---|---|
| CRL valables 1 jour, n° 1, expirées depuis le 17/10 | service de mise à jour non actif |
| Aucune adresse CDP / AIA | certificats sans adresse de révocation |
| Clés des CA non exportables (SoftHSM) | conforme |

### Corrections des CA

| Erreur | Correction |
|---|---|
| URL du certificat de la Root saisie dans **Default CRL Issuer** | champ vidé ; URL déplacée dans **CA issuer Default URI** (Root et Intermediate) |
| CRL n° 2 générées avant cette correction | CRL n° 3 régénérées puis publiées |

L'Intermediate a été émis avant ces réglages : il n'a ni CDP ni AIA (`No extensions in certificate`). La chaîne reste
valide ; il est conservé.

### Profils : trois réglages affichés mais non enregistrés

L'export XML (`ca exportprofiles`) a montré l'écart entre l'écran et ce qu'EJBCA avait enregistré :

| Réglage enregistré | Valeur trouvée | Effet constaté | Correction |
|---|---|---|---|
| `availablebitlengths` | 3072 seulement | `Illegal key length, not authorized by certificate profile: 2048` | 2048/3072/4096 ; clé de l'ALB en RSA 3072 |
| `usedefaultcrldistributionpoint` | `false` | certificat n° 1 sans CDP | coché, enregistré, vérifié par l'export |
| `usecertificatestorage` / `storecertificatedata` | `false` | certificats n° 1 et 2 introuvables : `No certificate found` à la révocation | cochés ; certificat n° 3 enregistré (*Active* dans RA Web) |

Profil d'entité `EE-TLS-YOON` : username prérempli effacé, O/C rendus non modifiables, listes à sélection multiple
corrigées (erreur « Default certificate profile must be among available certificate profiles »), DNS Name rendu modifiable.

## 3. Le certificat de l'ALB

### Le nom de l'ALB a changé deux fois

| Nom | Sort |
|---|---|
| `alb-moustapha-dev-755009444…` | détruit avant l'émission |
| `alb-moustapha-dev-1842800432…` | détruit après la création de la CSR |
| `alb-moustapha-dev-2014044716…` | **actuel** |

### Trois émissions

| N° | Numéro de série | Problème | Sort |
|---|---|---|---|
| 1 | `02E091DB…C335` | pas de CDP | remplacé ; non révocable (non enregistré) |
| 2 | `35F1BE61…5D23` | CDP présent, mais non enregistré dans EJBCA | remplacé ; non révocable |
| 3 | `5D0C16B5…6AAC` | conforme | **en service** |

Les fichiers des n° 1 et 2 ont été supprimés de la VM. Les trois partagent la même clé, qui reste protégée
(VM, droits 600, et ACM). ACM ne conserve pas les versions remplacées.

### Commandes clés

```bash
openssl req -new -newkey rsa:3072 -nodes -keyout alb.key -out alb.csr -config alb.cnf
$EJBCA ra addendentity --username alb-yoon-dev --password "$CODE" --dn "CN=$ALB,O=YOON,C=SN" \
  --altname "dNSName=$ALB" --caname "Lab-IntermediateCA-SoftHSM2" --type 1 --token USERGENERATED \
  --certprofile TLS-SERVER-YOON --eeprofile EE-TLS-YOON
$EJBCA createcert --username alb-yoon-dev --password "$CODE" -c /tmp/alb.csr -f /tmp/alb.crt
aws acm import-certificate --certificate fileb://alb.crt --private-key fileb://alb.key \
  --certificate-chain fileb://../ca/intermediate-ca.pem …                       # 1er import
aws acm import-certificate --certificate-arn "$ARN" …                           # réimports n° 2 et 3
```

### Pourquoi la CLI EJBCA plutôt que l'interface

L'interface affichait des réglages non enregistrés ; la CLI et l'export XML montrent l'état réel. Elle évite aussi les
fautes de frappe sur un nom de 57 caractères, garde la CSR et la clé dans la VM et permettra d'automatiser la
réémission. L'interface reste l'outil de configuration et de contrôle visuel (RA Web → Search → Certificates).

## 4. Activation (PR #16)

```hcl
# environments/dev/terraform.tfvars
certificate_arn = "arn:aws:acm:eu-west-3:231644789895:certificate/5c6f0b7d-92c0-4568-87f5-8c4fb01fa4ce"
```

Apply : `Apply complete! Resources: 1 added, 1 changed, 0 destroyed.` ; `load_balancer_url` en `https://`.
Avertissement du provider `Invalid Attribute Combination` lors du passage du port 80 en redirection : sans effet.

## 5. Appareils

| Appareil | Méthode | Résultat |
|---|---|---|
| Windows | `certutil -user -addstore Root …` (sans droits admin) | empreinte `bdc13c57…6a5a` identique à celle de la VM |
| Firefox (Windows) | reprise du magasin Windows | cadenas, « Vérifiée par : PKI LAB » |
| Android (Samsung) | Paramètres → Certificat AC (toucher le fichier est refusé) | cadenas ; caméra autorisée |

## 6. Incidents hors PKI

| Incident | Cause | Solution |
|---|---|---|
| Écran noir puis kernel panic de la VM | Additions invité VirtualBox installées depuis le CD (`vboxguest(OE)`), extinctions forcées | instantané, `fsck.ext4 -f -y /dev/sda3`, GRUB `nomodeset module_blacklist=vboxguest`, désinstallation |
| Instantané `Avant-reparation-Ubuntu` du 09/10 | antérieur aux CA | **non restauré** ; nouvel instantané `pki-avant-fsck-2026-11-06` |
| `aws login` refusé dans la VM | navigateur non relié, puis mot de passe saisi au lieu du code | `--remote` et code de vérification |
| `dev` détruit deux fois | arrêt des coûts | recréation, puis réémission |

## 7. Points ouverts

- [ ] **Délai de paiement dépassé dès l'ouverture** : le scanner affichait 23:41 quand le téléphone affichait 00:41.
      Hypothèse : dates renvoyées sans fuseau (serveur en UTC, navigateur en UTC+1), délai de 15 min vu comme écoulé.
      À confirmer, puis renvoyer des dates ISO 8601 avec fuseau.
- [ ] `db_password` en clair dans `environments/dev/terraform.tfvars` (la pipeline utilise le secret via `-var`) :
      retirer la ligne et changer le secret.
- [ ] Mot de passe de la console AWS exposé : le changer, activer la MFA.
- [ ] Confirmer le service EJBCA *CRL Updater* ; automatiser la copie des CRL vers S3.
- [ ] Prochaine publication de la CRL de l'Intermediate avant le **17/11/2026** (n° 4).
- [ ] Script de réémission après recréation de `dev`.
- [ ] Sauvegarde de SoftHSM et de la base EJBCA hors de la VM.
