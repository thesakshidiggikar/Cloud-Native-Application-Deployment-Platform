terraform {
  required_version = ">= 1.11.1, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 6.59.0, < 7.0.0" }
  }
  # Configure a private S3 backend via backend.hcl (ignored) before production use.
  backend "s3" {
    bucket = "REPLACE_WITH_PRIVATE_STATE_BUCKET"
    key    = "devopshere/terraform.tfstate"
    region = "REPLACE_ME"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = merge(var.tags, { Project = var.project_name, ManagedBy = "Terraform" }) }
}

data "aws_availability_zones" "available" { state = "available" }
data "aws_caller_identity" "current" {}

module "vpc" {
  source                       = "terraform-aws-modules/vpc/aws"
  version                      = "6.6.1"
  name                         = "${var.project_name}-${var.environment}"
  cidr                         = var.vpc_cidr
  azs                          = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets               = [cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2)]
  private_subnets              = [cidrsubnet(var.vpc_cidr, 8, 11), cidrsubnet(var.vpc_cidr, 8, 12)]
  database_subnets             = [cidrsubnet(var.vpc_cidr, 8, 21), cidrsubnet(var.vpc_cidr, 8, 22)]
  enable_nat_gateway           = true
  single_nat_gateway           = var.single_nat_gateway
  one_nat_gateway_per_az       = !var.single_nat_gateway
  enable_dns_hostnames         = true
  enable_dns_support           = true
  create_database_subnet_group = true
  database_subnet_group_name   = "${var.project_name}-${var.environment}-db"
  public_subnet_tags           = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags          = { "kubernetes.io/role/internal-elb" = "1", "karpenter.sh/discovery" = "${var.project_name}-${var.environment}" }
  tags                         = var.tags
}

module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "21.24.1"
  name                                     = "${var.project_name}-${var.environment}"
  kubernetes_version                       = var.kubernetes_version
  endpoint_public_access                   = true
  endpoint_private_access                  = true
  endpoint_public_access_cidrs             = var.cluster_admin_cidrs
  enable_irsa                              = true
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  control_plane_subnet_ids                 = module.vpc.private_subnets
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true
  addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    metrics-server         = { most_recent = true }
  }
  eks_managed_node_groups = {
    system = {
      name           = "system"
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      subnet_ids     = module.vpc.private_subnets
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2023_x86_64_STANDARD"
      update_config  = { max_unavailable_percentage = 33 }
      labels         = { workload = "system" }
    }
  }
  tags = var.tags
}

resource "aws_security_group" "database" {
  name_prefix = "${var.project_name}-${var.environment}-database-"
  description = "PostgreSQL from EKS nodes only"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description     = "PostgreSQL from EKS node security group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_db_subnet_group" "database" {
  name       = "${var.project_name}-${var.environment}"
  subnet_ids = module.vpc.database_subnets
  tags       = var.tags
}

resource "aws_db_instance" "database" {
  identifier                      = "${var.project_name}-${var.environment}"
  engine                          = "postgres"
  engine_version                  = var.postgres_engine_version
  instance_class                  = var.database_instance_class
  allocated_storage               = var.database_allocated_storage_gib
  max_allocated_storage           = var.database_max_allocated_storage_gib
  storage_type                    = "gp3"
  storage_encrypted               = true
  db_name                         = "devopshere"
  username                        = "devopshere_admin"
  manage_master_user_password     = true
  db_subnet_group_name            = aws_db_subnet_group.database.name
  vpc_security_group_ids          = [aws_security_group.database.id]
  publicly_accessible             = false
  multi_az                        = var.database_multi_az
  backup_retention_period         = var.database_backup_retention_days
  deletion_protection             = var.environment == "prod"
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${var.project_name}-${var.environment}-final"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  auto_minor_version_upgrade      = true
  apply_immediately               = false
  tags                            = var.tags
}

resource "aws_security_group" "cache" {
  name_prefix = "${var.project_name}-${var.environment}-cache-"
  description = "Redis from EKS nodes only"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description     = "Redis from EKS node security group"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_elasticache_subnet_group" "cache" {
  name       = "${var.project_name}-${var.environment}"
  subnet_ids = module.vpc.database_subnets
}

resource "aws_elasticache_replication_group" "cache" {
  replication_group_id       = "${var.project_name}-${var.environment}"
  description                = "Devopshere disposable task API cache"
  engine                     = "redis"
  engine_version             = var.redis_engine_version
  node_type                  = var.cache_node_type
  num_cache_clusters         = var.cache_nodes
  parameter_group_name       = "default.redis7"
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.cache.name
  security_group_ids         = [aws_security_group.cache.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  automatic_failover_enabled = var.cache_nodes > 1
  multi_az_enabled           = var.cache_nodes > 1
  apply_immediately          = false
  tags                       = var.tags
}

output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "database_secret_arn" { value = aws_db_instance.database.master_user_secret[0].secret_arn }
output "redis_endpoint" { value = aws_elasticache_replication_group.cache.primary_endpoint_address }
resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}/${var.environment}/api"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({ rules = [
    { rulePriority = 1, description = "Keep recent versioned releases", selection = { tagStatus = "tagged", tagPrefixList = ["v"], countType = "imageCountMoreThan", countNumber = 20 }, action = { type = "expire" } },
    { rulePriority = 2, description = "Remove old untagged images", selection = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 14 }, action = { type = "expire" } }
  ] })
}

resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu-high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.database.identifier }
  treat_missing_data  = "notBreaching"
  alarm_description   = "RDS CPU above 80% for 15 minutes."
  tags                = var.tags
}
resource "aws_cloudwatch_metric_alarm" "database_storage" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-storage-low"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 5368709120
  comparison_operator = "LessThanThreshold"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.database.identifier }
  treat_missing_data  = "notBreaching"
  alarm_description   = "RDS free storage below 5 GiB."
  tags                = var.tags
}
resource "aws_cloudwatch_metric_alarm" "cache_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-cpu-high"
  namespace           = "AWS/ElastiCache"
  metric_name         = "EngineCPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  dimensions          = { CacheClusterId = tolist(aws_elasticache_replication_group.cache.member_clusters)[0] }
  treat_missing_data  = "notBreaching"
  alarm_description   = "Redis engine CPU above 80% for 15 minutes."
  tags                = var.tags
}
output "ecr_repository_url" { value = aws_ecr_repository.api.repository_url }
output "ecr_repository_arn" { value = aws_ecr_repository.api.arn }

locals {
  cluster_oidc_hostpath = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
}

data "aws_iam_policy_document" "cloudwatch_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.cluster_oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.cluster_oidc_hostpath}:sub"
      values   = ["system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"]
    }
  }
}
resource "aws_iam_role" "cloudwatch_agent" {
  name               = "${var.project_name}-${var.environment}-cloudwatch-agent"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_assume_role.json
  tags               = var.tags
}
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "amazon-cloudwatch-observability"
  service_account_role_arn    = aws_iam_role.cloudwatch_agent.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_iam_role_policy_attachment.cloudwatch_agent]
  tags                        = var.tags
}






