#---------------------------
# input variables

variable "aws_default_region" {
  type = "string"
  default = "us-west-2"
}


variable "packer_ami" {
  type = "string"

  # packer created 
  default = "ami-038ba448c500c6c93"

  # ubuntu -- for test
  # default = "ami-4e79ed36"
}

#---------------------------
# output variables

# output "gtm_elastic_ip" {
#   value = "${aws_eip.eip_gtm.public_ip}"
# }


# output "coordinator_elastic_ip" {
#   value = "${aws_eip.eip_coordinator.public_ip}"
# }


output "public_ip_gtm" {
  value = "${aws_instance.gtm.public_ip}"
}

output "public_ip_coordinator" {
  value = "${aws_instance.coordinator.public_ip}"
}


output "private_ip_gtm" {
  value = "${aws_instance.gtm.private_ip}"
}

output "private_ip_coordinator" {
  value = "${aws_instance.coordinator.private_ip}"
}

output "private_ip_datanode_1" {
  value = "${aws_instance.datanode_1.private_ip}"
}

output "private_ip_datanode_2" {
  value = "${aws_instance.datanode_2.private_ip}"
}


#---------------------------
# providers

provider "aws" {
  version = "~> 1.29"

  region = "${var.aws_default_region}"
}


#---------------------------
# SETUP


resource "aws_instance" "gtm" {
  # Packer machine
  ami = "${var.packer_ami}"

  instance_type = "t2.xlarge"

  key_name = "leo-IAM-keypair"

  associate_public_ip_address = true

  private_ip = "172.31.45.190"

  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]


  provisioner "remote-exec" {
    script = "setup_cluster.sh",
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("leo-IAM-keypair.pem")}"
    }
  }


  tags {
    Name = "demo-GTM"
  }
}


resource "aws_instance" "coordinator" {
  # Packer machine
  ami = "${var.packer_ami}"

  instance_type = "t2.xlarge"

  key_name = "leo-IAM-keypair"

  private_ip = "172.31.45.191"

  associate_public_ip_address = true

  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]

  # vpc_security_group_ids = [ "sg-08d59420001117bcf" ]
  # subnet_id = "subnet-074f4ebe86e94133e"

  tags {
    Name = "demo-Coordinator"
  }
}


resource "aws_instance" "datanode_1" {
  # Packer machine
  ami = "${var.packer_ami}"

  instance_type = "t2.xlarge"

  key_name = "leo-IAM-keypair"

  private_ip = "172.31.45.192"

  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]

  # vpc_security_group_ids = [ "sg-08d59420001117bcf" ]
  # subnet_id = "subnet-074f4ebe86e94133e"

  tags {
    Name = "demo-Datanode_1"
  }
}


resource "aws_instance" "datanode_2" {
  # Packer machine
  ami = "${var.packer_ami}"

  instance_type = "t2.xlarge"

  key_name = "leo-IAM-keypair"

  private_ip = "172.31.45.193"

  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]

  # vpc_security_group_ids = [ "sg-08d59420001117bcf" ]
  # subnet_id = "subnet-074f4ebe86e94133e"

  tags {
    Name = "demo-Datanode_2"
  }
}



# setup elastic IP for the GTM
# resource "aws_eip" "eip_gtm" {
#   vpc = true

#   instance = "${aws_instance.gtm.id}"
# }


# setup elastic IP for the coordinator
# resource "aws_eip" "eip_coordinator" {
#   vpc = true

#   instance = "${aws_instance.coordinator.id}"
# }


# create security group that allows traffic in the port
resource "aws_security_group" "cluster_security_group" {
  name = "demo-cluster_security_group"

  ingress {
    from_port = "3000"
    to_port = "60000"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow connections between instances in the security group
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
