environment  = "prod"
cluster_name = "retail-cluster-prod"
vpc_name     = "retail-vpc-prod"

vpc_cidr_block     = "10.2.0.0/16"
public_subnets     = ["10.2.1.0/24", "10.2.2.0/24"]
private_subnets    = ["10.2.3.0/24", "10.2.4.0/24"]
availability_zones = ["us-east-1a", "us-east-1b"]
