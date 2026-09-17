variable "aws_region" {
  type = string
}

variable "plan_only" {
  type    = bool
  default = false
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "single_nat_gateway" {
  type = bool
}

variable "container_image" {
  type = string
}

variable "ecs_cpu" {
  type = number
}

variable "ecs_memory" {
  type = number
}

variable "ecs_desired_count" {
  type = number
}

variable "rds_instance_class" {
  type = string
}

variable "rds_allocated_storage" {
  type = number
}

variable "rds_backup_retention" {
  type = number
}

variable "rds_deletion_protection" {
  type = bool
}

variable "rds_multi_az" {
  type = bool
}

variable "tags" {
  type    = map(string)
  default = {}
}
