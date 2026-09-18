variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "redstar-server"
}

variable "instance_type" {
  description = "EC2 instance type supporting nested virtualization"
  type        = string
  default     = "c8i.xlarge"
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 80
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the EC2 instance"
  type        = string
  default     = "0.0.0.0/0"
}
