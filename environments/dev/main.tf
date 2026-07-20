module "network" {
  source = "../../modules/network"
}

module "data" {
  source = "../../modules/data"
}

module "lambda_128" {
  source          = "../../modules/lambda-variant"
  memory_size     = 128
  lambda_zip_path = var.lambda_zip_path
  table_name      = module.data.table_name
  table_arn       = module.data.table_arn
}

module "lambda_1024" {
  source          = "../../modules/lambda-variant"
  memory_size     = 1024
  lambda_zip_path = var.lambda_zip_path
  table_name      = module.data.table_name
  table_arn       = module.data.table_arn
}

module "fargate" {
  source             = "../../modules/fargate-variant"
  task_cpu           = var.fargate_task_cpu
  task_memory        = var.fargate_task_memory
  image_uri          = var.ecr_image_uri
  table_name         = module.data.table_name
  table_arn          = module.data.table_arn
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
}

module "ec2" {
  source             = "../../modules/ec2-variant"
  instance_type      = var.ec2_instance_type
  image_uri          = var.ecr_image_uri
  table_name         = module.data.table_name
  table_arn          = module.data.table_arn
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
}