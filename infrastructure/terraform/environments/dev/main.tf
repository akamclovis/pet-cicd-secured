module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  project_name = var.project_name
  environment  = var.environment
}

module "ecs_capacity" {
  source = "../../modules/ecs-capacity"

  project_name          = var.project_name
  environment           = var.environment
  cluster_name          = module.ecs_cluster.cluster_name
  ecs_security_group_id = module.networking.ecs_security_group_id
  private_subnet_ids    = module.networking.private_subnet_ids

  instance_type = var.ecs_instance_type
}

module "networking" {
  source = "../../modules/networking"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id

  application_port = 8080
}

module "ecs_service" {
  source = "../../modules/ecs-service"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  container_image = var.container_image
  container_port  = 8080

  cluster_arn            = module.ecs_cluster.cluster_arn
  capacity_provider_name = module.ecs_capacity.capacity_provider_name
  target_group_arn       = module.alb.target_group_arn

  desired_count = 1
}