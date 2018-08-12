############################################# PROVIDERS

provider "aws" {
  version = "~> 1.29"

  region = "${var.aws_default_region}"
}


############################################# CLUSTER CONFIGURATION
## COORDINATORS
resource "aws_launch_configuration" "coordinators" {
  name = "coordinators_asg"

  image_id = "${data.aws_ami.cluster_instance_ami.image_id}"
  instance_type = "${var.instance_type}"
  security_groups = [ "${aws_security_group.cluster_security_group.id}" ]
  key_name = "${var.keypair_name}"

  user_data = <<-EOF
              #!/bin/bash
              SERVER_COUNT="${var.consul_masters}" CONSUL_JOIN="${aws_instance.gtm.private_ip}" /bin/bash /home/ubuntu/consul_init.sh client coordinators
              EOF

  lifecycle {
    create_before_destroy = true
  }
}


## DATANODES
resource "aws_launch_configuration" "datanodes" {
  name = "datanodes_asg"

  image_id = "${data.aws_ami.cluster_instance_ami.image_id}"
  instance_type = "${var.instance_type}"
  security_groups = [ "${aws_security_group.cluster_security_group.id}" ]
  key_name = "${var.keypair_name}"

  user_data = <<-EOF
              #!/bin/bash
              SERVER_COUNT="${var.consul_masters}" CONSUL_JOIN="${aws_instance.gtm.private_ip}" /bin/bash /home/ubuntu/consul_init.sh client datanodes
              EOF

  lifecycle {
    create_before_destroy = true
  }
}


# resource "aws_launch_configuration" "gtm" {
#   name = "gtm_asg"
#
#   image_id = "${data.aws_ami.cluster_master_ami.image_id}"
#   instance_type = "${var.instance_type}"
#   security_groups = [ "${aws_security_group.cluster_security_group.id}" ]
#   key_name = "${var.keypair_name}"
#
#   user_data = <<-EOF
#               #!/bin/bash
#               /bin/bash /home/ubuntu/init_postgres_xl_master.sh
#               SERVER_COUNT="${var.consul_masters}" CONSUL_JOIN="${aws_instance.gtm.private_ip}" /bin/bash /home/ubuntu/consul_init.sh server gtm_asg
#               EOF
#
#   lifecycle {
#     create_before_destroy = true
#   }
# }



############################################# CLUSTER DEPLOY
## COORDINATORS
resource "aws_autoscaling_group" "coordinators" {
  launch_configuration = "${aws_launch_configuration.coordinators.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  # load balancer
  load_balancers = ["${aws_elb.coordinators.name}"]
  # health_check_type = "ELB"

  min_size = "${lookup(var.coordinators_layer, "min")}"
  max_size = "${lookup(var.coordinators_layer, "max")}"

  tag {
    key = "Name"
    value = "Coordinator"
    propagate_at_launch = true
  }
}


## DATANODES
resource "aws_autoscaling_group" "datanodes" {
  launch_configuration = "${aws_launch_configuration.datanodes.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  min_size = "${lookup(var.datanode_layer, "min")}"
  max_size = "${lookup(var.datanode_layer, "max")}"

  tag {
    key = "Name"
    value = "Datanode"
    propagate_at_launch = true
  }
}


# ## GTM ASG MASTERS
# resource "aws_autoscaling_group" "gtm" {
#   launch_configuration = "${aws_launch_configuration.gtm.id}"
#   availability_zones = ["${data.aws_availability_zones.all.names}"]
#
#   min_size = "${lookup(var.gtm_layer, "min")}"
#   max_size = "${lookup(var.gtm_layer, "max")}"
#
#   tag {
#     key = "Name"
#     value = "Gtm ASG"
#     propagate_at_launch = true
#   }
# }



## GTM
resource "aws_instance" "gtm" {
  # master
  tags {
    Name = "GTM"
  }

  ami = "${data.aws_ami.cluster_master_ami.image_id}"                               # packer created machine
  instance_type = "${var.instance_type}"                                            # machine specs
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]    # network group
  key_name = "${var.keypair_name}"                                                  # keypair configured service by amazon

  # run setup cluster
  provisioner "remote-exec" {
    inline = [
      "/home/ubuntu/init_postgres_xl_master.sh",
      "SERVER_COUNT=${var.consul_masters} CONSUL_JOIN=${aws_instance.gtm.private_ip} /home/ubuntu/consul_init.sh server gtm"
    ]
    # "nohup perl /home/ubuntu/monitor.pl &",
    # "sleep 1"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }

}



## CONSUL MASTER
# resource "aws_instance" "consul_master" {
#   # GTM proxy
#   tags {
#     Name = "Consul master"
#   }
#
#
#   ami = "${data.aws_ami.cluster_instance_ami.image_id}"
#   instance_type = "${var.consul_instance_type}"                                            # machine specs
#   vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]    # network group
#   key_name = "${var.keypair_name}"                                                  # keypair configured service by amazon
#
#   provisioner "remote-exec" {
#     inline = [
#       "SERVER_COUNT=${var.consul_masters} CONSUL_JOIN=${aws_instance.gtm.private_ip} /home/ubuntu/consul_init.sh consul master"
#     ]
#
#     connection {
#       type     = "ssh"
#       user     = "ubuntu"
#       private_key = "${file("resources/${var.keypair_name}.pem")}"
#     }
#   }
# }


## GTM Proxy
resource "aws_instance" "gtm_proxy" {
  # GTM proxy
  tags {
    Name = "GTM proxy"
  }


  ami = "${data.aws_ami.cluster_instance_ami.image_id}"
  instance_type = "${var.instance_type}"                                            # machine specs
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]    # network group
  key_name = "${var.keypair_name}"                                                  # keypair configured service by amazon

  provisioner "remote-exec" {
    inline = [
      "SERVER_COUNT=${var.consul_masters} CONSUL_JOIN=${aws_instance.gtm.private_ip} /home/ubuntu/consul_init.sh server gtm_proxy"
    ]

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }
}

############################################# LOAD BALANCERS
## COORDINATORS
resource "aws_elb" "coordinators" {
  name = "ELB-coordinators"

  security_groups = [ "${aws_security_group.cluster_security_group.id}" ]
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  # periodically check the health of the EC2 Instances
  # health_check {
  #   healthy_threshold = 2
  #   unhealthy_threshold = 2
  #   timeout = 3
  #   interval = 30
  #   target = "HTTP:30001/"
  # }



  listener {
    # receive
    lb_port = 80
    lb_protocol = "http"

    # send
    instance_port = "30001"
    instance_protocol = "http"
  }
}


############################################# NETWORK
# create security group that allows traffic in the needed port
resource "aws_security_group" "cluster_security_group" {
  name = "postgis_cluster_security_group"

  # open port range
  ingress {
    from_port = "3000"
    to_port = "60000"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow shh
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
