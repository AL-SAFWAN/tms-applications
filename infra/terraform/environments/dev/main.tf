module "vpc" {
  source = "../../modules/vpc"

  environment           = var.environment
  eks_name              = local.eks_name
  zone_1                = local.zone_1
  zone_2                = local.zone_2
  vpc_cidr              = "10.0.0.0/16"
  private_subnet_1_cidr = "10.0.0.0/19"
  private_subnet_2_cidr = "10.0.32.0/19"
  public_subnet_1_cidr  = "10.0.64.0/19"
  public_subnet_2_cidr  = "10.0.96.0/19"
}

module "eks" {
  source = "../../modules/eks"

  environment     = var.environment
  eks_name        = local.eks_name
  eks_version     = local.eks_version
  private_subnets = module.vpc.private_subnets

}


module "iam_developer" {
  source          = "../../modules/iam/iam-dev"
  environment     = var.environment
  cluster_name    = module.eks.cluster_name
  developer_username = "developer"
}

module "iam_admin" {
  source        = "../../modules/iam/iam-admin"
  environment   = var.environment
  eks_name      = local.eks_name
  cluster_name  = module.eks.cluster_name
  manager_username = "manager" 
}

module "iam_lbc" {
  # requires pod identity addon
  source        = "../../modules/iam/iam-lbc"
  environment   = var.environment
  cluster_name  = module.eks.cluster_name
}

module "iam_secrets" {
  source               = "../../modules/iam/iam-secrets"
  environment          = var.environment
  cluster_name         = module.eks.cluster_name

  federated_identity_arn = module.eks.federated_identity_arn
  federated_identity_url = module.eks.federated_identity_url
  service_account_name = "myapp" 
}



data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "db-cred"
}

locals {
  db_cred = jsondecode(
    data.aws_secretsmanager_secret_version.creds.secret_string
  )
}

module "db" {
  source = "../../modules/db"

  environment     = var.environment
  eks_name        = local.eks_name
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  db_username     = local.db_cred.username
  db_password     = local.db_cred.password
}



resource "helm_release" "web-app" {
  name      = "web-app-release" # This value becomes .Release.Name in templates
  chart     = "../../helm/web-app" # This is the path to the chart directory
  namespace = "kube-system"
  timeout   = 300 # 5 minute timeout
  wait      = true

  values = [
    file("${path.module}/../../helm/web-app/values.yaml"),
    jsonencode({
      serviceAccount = {
        create = true
        name   = "myapp"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.iam_secrets.role_arn
        }
      },
      backend = {
        extraEnv = [
          {
            name  = "POSTGRES_SERVER"
            value = replace(module.db.db_endpoint, ":5432", "") 
          },
          {
            name  = "POSTGRES_PORT"
            value = tostring(module.db.db_port)
          },
          {
            name  = "POSTGRES_DB"
            value = module.db.db_name
          },
          # {
          #   name  = "POSTGRES_USER"
          #   value = aws_db_instance.postgres.username
          # },
          # {
          #   name  = "POSTGRES_PASSWORD"
          #   value = aws_db_instance.postgres.password
          # }
        ]
      }
    })
  ]

  depends_on = [
    helm_release.aws_lbc,
    helm_release.secrets_csi_driver_aws_provider,
    helm_release.secrets_csi_driver,
  ]
}



# Retrieve your hosted zone
data "aws_route53_zone" "selected" {
  name = local.domain_name
}




data "aws_lb" "ingress_lb" {
# tags = {
#     "kubernetes.io/ingress-name" = "kube-system/web-app-release"
#   }
depends_on = [
    helm_release.aws_lbc,     
    helm_release.web-app,     
  ]
}

resource "aws_route53_record" "frontend-domain-record" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = local.full_domain
  type    = "CNAME"
  ttl     = 300
  
  records = [data.aws_lb.ingress_lb.dns_name]
  depends_on = [
    data.aws_lb.ingress_lb
  ]
}

resource "aws_route53_record" "backend-domain-record" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = local.api_full_domain
  type    = "CNAME"
  ttl     = 300

records = [data.aws_lb.ingress_lb.dns_name]
  depends_on = [
    data.aws_lb.ingress_lb
  ]
  
}
