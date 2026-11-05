# ---------------------------------------------------------
# Publication de la PKI (EJBCA / SoftHSM) : CRL et certificats de CA
# ---------------------------------------------------------
#
# Les navigateurs et outils de vérification téléchargent ces fichiers
# aux adresses inscrites dans les certificats :
#   - CDP (CRL Distribution Point) : liste des certificats révoqués ;
#   - AIA (Authority Information Access) : certificat de l'autorité émettrice.
#
# Ces adresses doivent :
#   - être en HTTP (pas HTTPS) : sinon, vérifier le certificat HTTPS
#     demanderait de vérifier... un autre certificat HTTPS ;
#   - ne jamais changer : elles sont figées dans chaque certificat émis.
#
# D'où un bucket dédié, permanent (bootstrap), indépendant de l'ALB.
# Seuls les dossiers crl/ et ca/ sont lisibles publiquement.
# Aucune clé privée ne doit jamais y être déposée.

locals {
  # Nom unique au monde : changez-le si AWS répond BucketAlreadyExists.
  pki_bucket   = "pki-moustapha-2026"
  pki_base_url = "http://${local.pki_bucket}.s3.eu-west-3.amazonaws.com"
}

resource "aws_s3_bucket" "pki" {
  bucket = local.pki_bucket

  tags = {
    Name    = local.pki_bucket
    Project = "moustapha"
    Usage   = "Publication des CRL et certificats de CA"
  }
}

# Conserve les versions précédentes des CRL (audit, retour arrière).
resource "aws_s3_bucket_versioning" "pki" {
  bucket = aws_s3_bucket.pki.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pki" {
  bucket = aws_s3_bucket.pki.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Les ACL restent bloquées ; seule la politique ci-dessous peut ouvrir la lecture.
resource "aws_s3_bucket_public_access_block" "pki" {
  bucket = aws_s3_bucket.pki.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

# Lecture publique limitée aux dossiers crl/ et ca/.
resource "aws_s3_bucket_policy" "pki" {
  bucket = aws_s3_bucket.pki.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "LecturePubliqueCrlEtCa"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          "${aws_s3_bucket.pki.arn}/crl/*",
          "${aws_s3_bucket.pki.arn}/ca/*",
        ]
      }
    ]
  })

  # La politique publique n'est acceptée qu'une fois le blocage levé.
  depends_on = [aws_s3_bucket_public_access_block.pki]
}
