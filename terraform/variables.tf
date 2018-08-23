############################################# DATA
## DEFAULT VPC
data "aws_vpc" "default" {
  tags = {
    # "Name"= "leo-vpc"
    "Name" = "Default"
  }
}

## DEFAULT SUBNET
data "aws_subnet_ids" "public" {
  vpc_id = "${data.aws_vpc.default.id}"
}


# find the last packer image created for the master
data "aws_ami" "cluster_master_ami" {
  most_recent = true
  owners = ["self"]

  filter {
    name   = "name"
    values = ["master-postgis-xl-*"]
  }
}

# find the last packer image created for the master
data "aws_ami" "cluster_instance_ami" {
  most_recent = true
  owners = ["self"]

  filter {
    name   = "name"
    values = ["instance-postgis-xl-*"]
  }
}

# availability zones to deploy the instances
# default -> all availability zones
data "aws_availability_zones" "all" {}

############################################# VARIABLES
variable "monitor_instance_ami" {
  description = "AMI type used for the grafana and API instance, the default is Ubuntu (ami-4e79ed362)"
  type = "string"
  default = "ami-4e79ed36"
}

# default region to work
variable "aws_default_region" {
  type = "string"
  default = "us-west-2"
}

# machine type that will be used to deploy the infraestructure
variable "instance_type" {
  type = "string"

  default = "t2.xlarge"
  # default = "t2.micro"
}

variable "keypair_name"{
  type = "string"

  default = "cluster-keypair"
}

### CONSUL VARIABLES
variable "consul_masters" {
  description = "Number of masters in the consul cluster"
  type = "string"
  default = "3"
}

# machine type for the master
variable "consul_instance_type" {
  type = "string"

  default = "t2.micro"
}


### POSTGRES-XL VARIABLES
variable "coordinators_layer" {
  description = "Default values for the cluster layer"
  type = "map"
  default = {
    "min" = "2"
    "max" = "10"
  }
}

variable "datanode_layer" {
  description = "Default values for the datanode layer"
  type = "map"
  default = {
    "min" = "2"
    "max" = "100"
  }
}

variable "gtm_layer" {
  description = "Default values for the GTM layer"
  type = "map"
  default = {
    "min" = "2"
    "max" = "2"
  }
}
