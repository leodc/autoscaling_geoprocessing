############################################# PROVIDERS

provider "aws" {
  version = "~> 1.29"

  region = "${var.aws_default_region}"
}


############################################# SETUP
/*
            COORDINATORS LAYER
*/

resource "aws_instance" "coordinator" {
  tags {
    Name = "Coordinator"
  }

  ami = "${data.aws_ami.cluster_ami.image_id}"
  instance_type = "${var.instance_type}"
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]
  key_name = "${var.keypair_name}"
}


/*
            DATANODES LAYER
*/

resource "aws_instance" "datanode_1" {
  tags {
    Name = "Datanode_1"
  }


  ami = "${data.aws_ami.cluster_ami.image_id}"
  instance_type = "${var.instance_type}"
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]
  key_name = "${var.keypair_name}"
}


resource "aws_instance" "datanode_2" {
  tags {
    Name = "Datanode_2"
  }


  ami = "${data.aws_ami.cluster_ami.image_id}"
  instance_type = "${var.instance_type}"
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]
  key_name = "${var.keypair_name}"

}

/*
            GTM LAYER
*/

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

  # upload cluster configuration file
  provisioner "file" {
    source = "resources/pgxc_ctl.conf"
    destination = "/home/ubuntu/pgxc_ctl.conf"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }

  # upload setup script
  provisioner "file" {
    source = "resources/setup_cluster.sh"
    destination = "/home/ubuntu/setup_cluster.sh"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }

  # run setup cluster
  provisioner "remote-exec" {
    inline = [
      "chmod a+x /home/ubuntu/setup_cluster.sh",
      "gtmSlaveServer='${aws_instance.gtm_slave.private_ip}' gtmProxyServers='${aws_instance.gtm_proxy.private_ip}' gtmMasterServer='${aws_instance.gtm.private_ip}' coordMasterServers_ips='${aws_instance.coordinator.private_ip}' datanodeMasterServers_ips='${aws_instance.datanode_1.private_ip} ${aws_instance.datanode_2.private_ip}' /home/ubuntu/setup_cluster.sh",
      "rm /home/ubuntu/setup_cluster.sh"
    ]

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }

}


resource "aws_instance" "gtm_proxy" {
  # GTM proxy
  tags {
    Name = "GTM proxy"
  }


  ami = "${data.aws_ami.cluster_ami.image_id}"
  instance_type = "${var.instance_type}"                                            # machine specs
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]    # network group
  key_name = "${var.keypair_name}"                                                  # keypair configured service by amazon
}


resource "aws_instance" "gtm_slave" {
  # GTM proxy
  tags {
    Name = "GTM slave"
  }


  ami = "${data.aws_ami.cluster_ami.image_id}"
  instance_type = "${var.instance_type}"                                            # machine specs
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]    # network group
  key_name = "${var.keypair_name}"                                                  # keypair configured service by amazon
}

/*
            NETWORK
*/

# create security group that allows traffic in the port
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
