aws_region  = "ap-south-1"
plan_only   = true
environment = "dev"
vpc_cidr    = "10.20.0.0/16"

availability_zones   = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]

single_nat_gateway = true

container_image   = "nginx:1.27-alpine"
ecs_cpu           = 256
ecs_memory        = 512
ecs_desired_count = 1

rds_instance_class      = "db.t4g.micro"
rds_allocated_storage   = 20
rds_backup_retention    = 3
rds_deletion_protection = false
rds_multi_az            = false

tags = {
  Project     = "tripare-devops-assessment"
  Environment = "dev"
  ManagedBy   = "terraform"
}
