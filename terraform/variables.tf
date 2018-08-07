############################################# DATA

# find the last packer image created
data "aws_ami" "cluster_ami" {
  most_recent = true
  owners = ["self"]

  filter {
    name   = "name"
    values = ["postgis-xl-*"]
  }
}

# availability zones to deploy the instances
data "aws_availability_zones" "all" {
}

############################################# VARIABLES

# default region to work
variable "aws_default_region" {
  type = "string"
  default = "us-west-2"
}

# machine type that will be used to deploy the infraestructure
variable "instance_type" {
  type = "string"

  default = "t2.xlarge"
}

variable "keypair_name"{
  type = "string"

  default = "cluster-keypair"
}
