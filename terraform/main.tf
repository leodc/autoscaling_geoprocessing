############################################# PROVIDERS

provider "aws" {
  version = "~> 1.29"

  region = "${var.aws_default_region}"
}


############################################# CLUSTER CONFIGURATION
## COORDINATORS
resource "aws_launch_configuration" "coordinators" {
  name = "coordinators_asg"

  image_id = "${data.aws_ami.cluster_ami.image_id}"
  instance_type = "${var.instance_type}"
  security_groups = [ "${aws_security_group.cluster_security_group.id}" ]
  key_name = "${var.keypair_name}"

  user_data = <<-EOF
              #!/bin/bash
              SERVER_COUNT="${var.consul_server_count}" CONSUL_JOIN="${aws_instance.gtm.private_ip}" /bin/bash /home/ubuntu/consul_init.sh client coordinators
              EOF

  lifecycle {
    create_before_destroy = true
  }
}


## WORKERS
resource "aws_launch_configuration" "workers" {
  name = "workers_asg"

  image_id = "${data.aws_ami.cluster_ami.image_id}"
  instance_type = "${var.instance_type}"
  security_groups = [ "${aws_security_group.cluster_security_group.id}" ]
  key_name = "${var.keypair_name}"

  user_data = <<-EOF
              #!/bin/bash
              SERVER_COUNT="${var.consul_server_count}" CONSUL_JOIN="${aws_instance.gtm.private_ip}" /bin/bash /home/ubuntu/consul_init.sh client workers
              EOF

  lifecycle {
    create_before_destroy = true
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



############################################# CLUSTER DEPLOY
## COORDINATORS
resource "aws_autoscaling_group" "coordinators" {
  launch_configuration = "${aws_launch_configuration.coordinators.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  # load balancer
  load_balancers = ["${aws_elb.coordinators.name}"]
  # health_check_type = "ELB"

  min_size = 2
  max_size = 5

  tag {
    key = "Name"
    value = "Coordinator"
    propagate_at_launch = true
  }
}


## WORKERS
resource "aws_autoscaling_group" "workers" {
  launch_configuration = "${aws_launch_configuration.workers.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  min_size = 4
  max_size = 10

  tag {
    key = "Name"
    value = "Worker"
    propagate_at_launch = true
  }
}




## GTM Proxy
resource "aws_instance" "gtm_proxy" {
  # GTM proxy
  tags {
    Name = "GTM proxy"
  }


  ami = "${data.aws_ami.cluster_ami.image_id}"
  instance_type = "${var.instance_type}"                                            # machine specs
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]    # network group
  key_name = "${var.keypair_name}"                                                  # keypair configured service by amazon

  provisioner "remote-exec" {
    inline = [
      "SERVER_COUNT=${var.consul_server_count} CONSUL_JOIN=${aws_instance.gtm.private_ip} /home/ubuntu/consul_init.sh server gtm_proxy"
    ]

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }
}

# GTM SLAVE
resource "aws_instance" "gtm_slave" {
  # GTM slave
  tags {
    Name = "GTM slave"
  }


  ami = "${data.aws_ami.cluster_ami.image_id}"
  instance_type = "${var.instance_type}"                                            # machine specs
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]    # network group
  key_name = "${var.keypair_name}"                                                  # keypair configured service by amazon

  provisioner "remote-exec" {
    inline = [
      "SERVER_COUNT=${var.consul_server_count} CONSUL_JOIN=${aws_instance.gtm.private_ip} /home/ubuntu/consul_init.sh server gtm_slave"
    ]

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }
}


## GTM
resource "aws_instance" "gtm" {
  # master
  tags {
    Name = "GTM"
  }

  ami = "${data.aws_ami.cluster_ami.image_id}"                                      # packer created machine
  instance_type = "${var.instance_type}"                                            # machine specs
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]    # network group
  key_name = "${var.keypair_name}"                                                  # keypair configured service by amazon

  # add shh key
  provisioner "file" {
    source = "resources/${var.keypair_name}.pem"
    destination = "/home/ubuntu/.ssh/id_ecdsa"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }

  # upload setup script
  provisioner "file" {
    source = "resources/init_postgres_xl_master.sh"
    destination = "/home/ubuntu/init_postgres_xl_master.sh"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }

  # run setup cluster
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/init_postgres_xl_master.sh",
      "chmod 400 /home/ubuntu/.ssh/id_ecdsa",
      "/home/ubuntu/init_postgres_xl_master.sh",
      "SERVER_COUNT=${var.consul_server_count} CONSUL_JOIN=${aws_instance.gtm.private_ip} /home/ubuntu/consul_init.sh server gtm"
    ]

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
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
