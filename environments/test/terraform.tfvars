environment  = "test"
cluster_name = "retail-cluster-test"
vpc_name     = "retail-vpc-test"

vpc_cidr_block    = "10.1.0.0/16"
public_subnets    = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnets   = ["10.1.3.0/24", "10.1.4.0/24"]
availability_zones = ["us-east-1a", "us-east-1b"]
