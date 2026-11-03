# ---------------------------------------------------------
# Registres d'images Docker (Amazon ECR) de l'application Yoon
# ---------------------------------------------------------
#
# Les images sont construites par les GitHub Actions des dépôts
# GestionVoyageBakend et GestionVoyageFrontend, puis tirées par les EC2.
#
# Ces registres sont placés dans le bootstrap, et non dans dev/staging/prod :
# - la même image est promue d'un environnement à l'autre ;
# - détruire dev ne doit pas supprimer les images.

locals {
  ecr_repositories = {
    api = "gestion-voyage-api"
    web = "gestion-voyage-web"
  }
}

resource "aws_ecr_repository" "app" {
  for_each = local.ecr_repositories

  name = each.value

  # MUTABLE : le tag "latest" peut être déplacé vers la nouvelle version.
  # Chaque image reçoit aussi un tag immuable de fait : le SHA du commit.
  image_tag_mutability = "MUTABLE"

  # Analyse de vulnérabilités à chaque push (gratuite, niveau basique).
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name    = each.value
    Project = "moustapha"
  }
}

# Garde les 15 dernières images de chaque registre pour limiter le coût
# du stockage, tout en permettant de revenir en arrière.
resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conserver les 15 images les plus recentes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 15
        }
        action = { type = "expire" }
      }
    ]
  })
}
