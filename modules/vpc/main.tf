# Un bloc resource décrit une ressource que Terraform doit gérer.
#
# Exemple : resource "aws_vpc" "main"
# - aws_vpc : type de ressource fourni par le fournisseur AWS.
# - main    : nom local utilisé pour référencer cette ressource dans Terraform.
#
# Le nom local "main" n'est pas le nom affiché dans AWS.
# Le nom affiché est généralement défini par le tag Name.


# ---------------------------------------------------------
# 1. VPC : réseau principal contenant les sous-réseaux
# ---------------------------------------------------------

resource "aws_vpc" "main" {
  # Plage IP du VPC, définie dans variables.tf.
  cidr_block = var.vpc_cidr

  # Active la résolution DNS fournie par AWS dans le VPC.
  enable_dns_support = true

  # Permet notamment l'attribution de noms DNS publics AWS
  # aux instances disposant d'une adresse IPv4 publique.
  enable_dns_hostnames = true

  # Les tags sont des étiquettes permettant d'identifier les ressources.
  # ${...} insère une valeur dans une chaîne de caractères.
  #
  # Exemple : vpc-moustapha-dev
  tags = {
    Name = "vpc-${var.project_name}-${var.env}"
  }
}


# ---------------------------------------------------------
# 2. Sous-réseaux publics
# ---------------------------------------------------------

resource "aws_subnet" "public" {
  # Crée autant de sous-réseaux que d'éléments dans la liste.
  # Avec deux CIDR, Terraform crée :
  # - aws_subnet.public[0]
  # - aws_subnet.public[1]
  count = length(var.public_subnet_cidr)

  # Place chaque sous-réseau dans le VPC créé plus haut.
  # Cette référence crée une dépendance implicite :
  # Terraform doit créer le VPC avant ses sous-réseaux.
  vpc_id = aws_vpc.main.id

  # count.index commence à 0.
  # Chaque sous-réseau reçoit le CIDR situé au même index.
  cidr_block = var.public_subnet_cidr[count.index]

  # Sélectionne la zone située au même index.
  # Exemple : le premier sous-réseau utilise eu-west-3a.
  availability_zone = var.availability_zones[count.index]

  # Active par défaut l'attribution d'une IPv4 publique aux instances
  # lancées dans ce sous-réseau ; ce réglage peut être remplacé au lancement.
  #
  # Cela ne suffit pas à autoriser les connexions :
  # les routes et les règles de sécurité doivent aussi les permettre.
  map_public_ip_on_launch = true

  tags = {
    # + 1 sert uniquement à afficher une numérotation commençant à 1.
    # Exemple : public-subnet-1-moustapha-dev
    Name = "public-subnet-${count.index + 1}-${var.project_name}-${var.env}"
  }
}


# ---------------------------------------------------------
# 3. Sous-réseaux privés
# ---------------------------------------------------------

resource "aws_subnet" "private" {
  # Crée un sous-réseau pour chaque CIDR privé.
  count = length(var.private_subnet_cidr)

  # Utilise le même VPC que les sous-réseaux publics.
  vpc_id = aws_vpc.main.id

  # Attribue à chaque sous-réseau sa plage IP et sa zone.
  cidr_block        = var.private_subnet_cidr[count.index]
  availability_zone = var.availability_zones[count.index]

  # Aucun réglage n'active ici l'attribution automatique d'IPv4 publiques.
  # Pour ces nouveaux sous-réseaux, elle est désactivée par défaut.
  #
  # Leur route vers Internet passera par la NAT Gateway,
  # configurée plus bas.

  tags = {
    Name = "private-subnet-${count.index + 1}-${var.project_name}-${var.env}"
  }
}


# ---------------------------------------------------------
# 4. Internet Gateway : liaison du VPC avec Internet
# ---------------------------------------------------------

resource "aws_internet_gateway" "main" {
  # Attache l'Internet Gateway au VPC.
  #
  # Elle permet les communications Internet des ressources admissibles,
  # à condition que les routes, adresses IP et règles de sécurité
  # soient correctement configurées.
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${var.project_name}-${var.env}"
  }
}


# ---------------------------------------------------------
# 5. Elastic IP : adresse IPv4 publique pour la NAT Gateway
# ---------------------------------------------------------

resource "aws_eip" "nat" {
  # Réserve une adresse IPv4 publique statique pour une utilisation VPC.
  # Cette adresse sera affectée à la NAT Gateway.
  domain = "vpc"

  tags = {
    Name = "nat-eip-${var.project_name}-${var.env}"
  }

  # Dépendance explicite : attend la création de l'Internet Gateway.
  # Cette instruction impose un ordre ; elle n'attache pas l'EIP à l'IGW.
  depends_on = [aws_internet_gateway.main]
}


# ---------------------------------------------------------
# 6. NAT Gateway : sortie Internet des sous-réseaux privés
# ---------------------------------------------------------

resource "aws_nat_gateway" "main" {
  # Affecte l'Elastic IP réservée à cette NAT Gateway.
  allocation_id = aws_eip.nat.id

  # Place la NAT Gateway dans le premier sous-réseau public.
  # Il faut donc au moins un élément dans public_subnet_cidr.
  subnet_id = aws_subnet.public[0].id

  # Les ressources privées pourront initier des connexions IPv4
  # vers Internet et recevoir les réponses via cette NAT.
  #
  # La NAT ne permet pas d'initier une connexion depuis Internet
  # vers les ressources privées.
  #
  # Une seule NAT est créée et partagée par tous les sous-réseaux privés.
  # Elle n'est donc pas redondante entre les zones.

  tags = {
    Name = "nat-gateway-${var.project_name}-${var.env}"
  }

  # Attend que l'Internet Gateway soit attachée au VPC.
  # Les références ci-dessus créent aussi des dépendances implicites
  # vers l'Elastic IP et le sous-réseau public.
  depends_on = [aws_internet_gateway.main]
}


# ---------------------------------------------------------
# 7. Table de routage publique
# ---------------------------------------------------------

resource "aws_route_table" "public" {
  # Crée une table de routage appartenant au VPC.
  vpc_id = aws_vpc.main.id

  route {
    # Route par défaut IPv4 :
    # destinations qui ne correspondent pas à une route plus précise.
    cidr_block = "0.0.0.0/0"

    # Envoie ce trafic vers l'Internet Gateway.
    gateway_id = aws_internet_gateway.main.id
  }

  # AWS ajoute automatiquement une route locale pour les échanges
  # à l'intérieur du VPC. Elle n'a pas besoin d'être déclarée ici.

  tags = {
    Name = "public-route-table-${var.project_name}-${var.env}"
  }
}


# ---------------------------------------------------------
# 8. Association des sous-réseaux publics à leur table
# ---------------------------------------------------------

resource "aws_route_table_association" "public" {
  # Crée une association pour chaque sous-réseau public.
  count = length(aws_subnet.public)

  # Tous les sous-réseaux publics utilisent la même table publique.
  route_table_id = aws_route_table.public.id

  # Sélectionne le sous-réseau correspondant à chaque association.
  subnet_id = aws_subnet.public[count.index].id
}


# ---------------------------------------------------------
# 9. Table de routage privée
# ---------------------------------------------------------

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    # Route par défaut IPv4 des sous-réseaux privés.
    cidr_block = "0.0.0.0/0"

    # Envoie le trafic vers la NAT Gateway.
    # Une NAT utilise nat_gateway_id, et non gateway_id.
    nat_gateway_id = aws_nat_gateway.main.id
  }

  # Le trajet sortant sera :
  # ressource privée -> NAT Gateway -> Internet Gateway -> Internet.
  #
  # Les échanges internes au VPC utilisent la route locale AWS.

  tags = {
    Name = "private-route-table-${var.project_name}-${var.env}"
  }
}


# ---------------------------------------------------------
# 10. Association des sous-réseaux privés à leur table
# ---------------------------------------------------------

resource "aws_route_table_association" "private" {
  # Crée une association pour chaque sous-réseau privé.
  count = length(aws_subnet.private)

  # Tous les sous-réseaux privés utilisent la même table privée.
  route_table_id = aws_route_table.private.id

  subnet_id = aws_subnet.private[count.index].id
}