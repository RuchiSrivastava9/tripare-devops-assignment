aws_region  = "ap-south-1"
plan_only   = true
environment = "prod"
vpc_cidr    = "10.20.0.0/16"

availability_zones   = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]

single_nat_gateway = false

container_image   = "nginx:1.27-alpine"
ecs_cpu           = 512
ecs_memory        = 1024
ecs_desired_count = 2

rds_instance_class      = "db.t4g.small"
rds_allocated_storage   = 50
rds_backup_retention    = 14
rds_deletion_protection = true
rds_multi_az            = true

tags = {
  Project     = "tripare-devops-assessment"
  Environment = "prod"
  ManagedBy   = "terraform"
}
