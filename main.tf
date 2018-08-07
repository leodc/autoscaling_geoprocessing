#---------------------------
# input variables

variable "aws_default_region" {
  type = "string"
  description = "Set through env var, is the region where terraform will deploy the services"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default = 22345
}

#---------------------------

#---------------------------
# output variables

output "load_balancer_entry" {
  value = "http://${aws_elb.web_cluster.dns_name}"
}

#---------------------------
# providers

provider "aws" {
  version = "~> 1.29"
  
  region = "${var.aws_default_region}"
}


#---------------------------
# SETUP

data "aws_availability_zones" "all" {}


# configuration for each machine in the cluster
# Red Hat Enterprise Linux 7.5 (HVM) -> ami-28e07e50
# Ubuntu Server 16.04 LTS (HVM) -> ami-ba602bc2
resource "aws_launch_configuration" "web_cluster" {
  # ubuntu
  image_id = "ami-ba602bc2"

  instance_type = "t2.micro"

  # created security group
  security_groups = [ "${aws_security_group.elb_web_cluster.id}" ]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}


# service deploy
resource "aws_autoscaling_group" "web_cluster" {
  launch_configuration = "${aws_launch_configuration.web_cluster.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  # load balancer 
  load_balancers = ["${aws_elb.web_cluster.name}"]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key = "Name"
    value = "web_cluster_example"
    propagate_at_launch = true
  }
}


# ElasticLoadBalancer
# As we have many machines we need to distribute the work,
# ElasticLoadBalancer from AWS is going to be in charge of sending client petitions to machines with low work
resource "aws_elb" "web_cluster" {
  name = "terraform-asg-web-cluster"

  # created security group
  security_groups = ["${aws_security_group.elb_web_cluster.id}"]

  availability_zones = ["${data.aws_availability_zones.all.names}"]


  # periodically check the health of the EC2 Instances 
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:${var.server_port}/"
  }



  listener {
    # receive
    lb_port = 80
    lb_protocol = "http"

    # send
    instance_port = "${var.server_port}"
    instance_protocol = "http"
  }
}


# create security group with lifecycle as needed
resource "aws_security_group" "elb_web_cluster" {
  name = "terraform-example-web-cluster"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ports open to the world
  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
