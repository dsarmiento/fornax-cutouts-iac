data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

locals {
  # Minimum number of address bits needed to index 2 × num_subnets subnets.
  # This also equals the newbits argument passed to cidrsubnet(), so the VPC
  # is exactly large enough to hold all subnets with no wasted space.
  index_bits     = ceil(log(var.num_subnets * 2, 2))
  vpc_prefix     = var.subnet_prefix - local.index_bits
  vpc_cidr       = "10.0.0.0/${local.vpc_prefix}"
  subnet_newbits = local.index_bits
}

resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "public" {
  count                   = var.num_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, local.subnet_newbits, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
}

resource "aws_subnet" "private" {
  count                   = var.num_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, local.subnet_newbits, var.num_subnets + count.index)
  map_public_ip_on_launch = false
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

# NAT Gateway — allows private subnets outbound internet access (e.g. DuckDB
# extension downloads) without exposing them to inbound traffic.
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.internet_gateway]
}

# Private route table — default route via NAT Gateway; AWS services via endpoints.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "public" {
  count          = var.num_subnets
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "private" {
  count          = var.num_subnets
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# # ---------------------------------------------------------------------------
# # VPC Endpoints — give private subnets direct access to AWS services without
# # requiring a NAT gateway or internet path.
# # ---------------------------------------------------------------------------

# # Security group shared by all interface endpoints: allow HTTPS from within VPC.
# resource "aws_security_group" "vpc_endpoints" {
#   name        = "vpc-endpoints-sg"
#   description = "Allow HTTPS from VPC to interface endpoints"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     description = "HTTPS from VPC"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = [aws_vpc.main.cidr_block]
#   }
# }

# # S3 — Gateway endpoint (free; needed for ECR to pull image layers stored in S3
# # and for application cutout output storage).
# resource "aws_vpc_endpoint" "s3" {
#   vpc_id            = aws_vpc.main.id
#   service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
#   vpc_endpoint_type = "Gateway"
#   route_table_ids   = [aws_route_table.private.id]
# }

# # ECR API — authenticate and fetch image manifests.
# resource "aws_vpc_endpoint" "ecr_api" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
# }

# # ECR DKR — pull image layers (the actual layer blobs come via S3 above).
# resource "aws_vpc_endpoint" "ecr_dkr" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
# }

# # CloudWatch Logs — ECS container log delivery and Lambda function logs.
# resource "aws_vpc_endpoint" "cloudwatch_logs" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
# }

# # CloudWatch Metrics — Lambda publishes queue-depth metrics via put_metric_data.
# resource "aws_vpc_endpoint" "cloudwatch_monitoring" {
#   vpc_id              = aws_vpc.main.id
#   service_name        = "com.amazonaws.${data.aws_region.current.name}.monitoring"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
# }
