############################################# PROVIDERS

provider "aws" {
  version = "~> 1.29"

  region = "${var.aws_default_region}"
}


############################################# ASG POLICY
## COORDINATORS
resource "aws_autoscaling_policy" "coordinators" {
  name = "coordinators-autoplicy"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.coordinators.name}"
}


resource "aws_autoscaling_policy" "coordinators-down" {
  name = "coordinators-autoplicy-down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.coordinators.name}"
}

## DATANODES
resource "aws_autoscaling_policy" "datanodes" {
  name = "datanodes-autoplicy"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.datanodes.name}"
}


resource "aws_autoscaling_policy" "datanodes-down" {
  name = "datanodes-autoplicy-down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.datanodes.name}"
}


############################################# ALARMS
## COORDINATORS
resource "aws_cloudwatch_metric_alarm" "coordinators" {
  alarm_name = "coordinators-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "60"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.coordinators.name}"
  }

  alarm_description = "This metric monitor EC2 instance cpu utilization"
  alarm_actions = ["${aws_autoscaling_policy.coordinators.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "coordinators-down" {
  alarm_name = "coordinators-alarm-down"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "10"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.coordinators.name}"
  }

  alarm_description = "This metric monitor EC2 instance cpu utilization"
  alarm_actions = ["${aws_autoscaling_policy.coordinators-down.arn}"]
}


## DATANODES
resource "aws_cloudwatch_metric_alarm" "datanodes" {
  alarm_name = "datanodes-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "60"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.datanodes.name}"
  }

  alarm_description = "This metric monitor EC2 instance cpu utilization"
  alarm_actions = ["${aws_autoscaling_policy.datanodes.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "datanodes-down" {
  alarm_name = "datanodes-alarm-down"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "10"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.datanodes.name}"
  }

  alarm_description = "This metric monitor EC2 instance cpu utilization"
  alarm_actions = ["${aws_autoscaling_policy.datanodes-down.arn}"]
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
              nohup /home/ubuntu/node_exporter-0.16.0.linux-amd64/node_exporter &
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
              nohup /home/ubuntu/node_exporter-0.16.0.linux-amd64/node_exporter &
              SERVER_COUNT="${var.consul_masters}" CONSUL_JOIN="${aws_instance.gtm.private_ip}" /bin/bash /home/ubuntu/consul_init.sh client datanodes
              EOF

  lifecycle {
    create_before_destroy = true
  }
}


############################################# CLUSTER DEPLOY
## COORDINATORS
resource "aws_autoscaling_group" "coordinators" {
  launch_configuration = "${aws_launch_configuration.coordinators.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  # load balancer
  # health_check_type = "ELB"

  target_group_arns = ["${aws_lb_target_group.coordinators.arn}"]

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
      "nohup /home/ubuntu/node_exporter-0.16.0.linux-amd64/node_exporter &",
      "SERVER_COUNT=${var.consul_masters} CONSUL_JOIN=${aws_instance.gtm.private_ip} /home/ubuntu/consul_init.sh server gtm_proxy"
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


  ami = "${data.aws_ami.cluster_instance_ami.image_id}"
  instance_type = "${var.instance_type}"                                            # machine specs
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]    # network group
  key_name = "${var.keypair_name}"                                                  # keypair configured service by amazon

  provisioner "remote-exec" {
    inline = [
      "nohup /home/ubuntu/node_exporter-0.16.0.linux-amd64/node_exporter &",
      "SERVER_COUNT=${var.consul_masters} CONSUL_JOIN=${aws_instance.gtm.private_ip} /home/ubuntu/consul_init.sh server gtm_slave"
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

  ami = "${data.aws_ami.cluster_master_ami.image_id}"                                      # packer created machine
  instance_type = "${var.instance_type}"                                            # machine specs
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]    # network group
  key_name = "${var.keypair_name}"                                                  # keypair configured service by amazon


  # upload monitor script
  provisioner "file" {
    source = "resources/monitor/monitor.pl"
    destination = "/home/ubuntu/monitor.pl"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }


  provisioner "file" {
    source = "resources/test/insert_data.sh"
    destination = "/home/ubuntu/insert_data.sh"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }


  # run setup cluster
  provisioner "remote-exec" {
    inline = [
      "MASTER_IP=${aws_instance.gtm.private_ip} /home/ubuntu/init_postgres_xl_master.sh",
      "SERVER_COUNT=${var.consul_masters} CONSUL_JOIN=${aws_instance.gtm.private_ip} /home/ubuntu/consul_init.sh server gtm",
      "chmod +x /home/ubuntu/insert_data.sh"
    ]

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }


  # install monitor tools
  provisioner "remote-exec" {
    scripts = [
      "resources/monitor/install_prometheus.sh",
      "resources/monitor/start_node_exporter.sh",
      "resources/monitor/start_consul_exporter.sh",
      "resources/monitor/install_monitor_script.sh"
    ]

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }

}



## Monitor
resource "aws_instance" "monitor" {
  # master
  tags {
    Name = "Monitor"
  }

  ami = "${var.monitor_instance_ami}"                                               # monitor ami
  instance_type = "${var.instance_type}"                                            # machine specs
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]    # network group
  key_name = "${var.keypair_name}"                                                  # keypair configured service by amazon


  # upload grafana installation script
  provisioner "file" {
    source = "resources/monitor/install_grafana.sh"
    destination = "/home/ubuntu/install_grafana.sh"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }


  provisioner "remote-exec" {
    inline = [
      "chmod a+x /home/ubuntu/install_grafana.sh",
      "PROMETHEUS_SOURCE=${aws_instance.gtm.private_ip} /home/ubuntu/install_grafana.sh"
    ]

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }

}



## Monitor
resource "aws_instance" "api" {
  # master
  tags {
    Name = "API"
  }

  ami = "${var.monitor_instance_ami}"                                               # monitor ami
  instance_type = "${var.instance_type}"                                            # machine specs
  vpc_security_group_ids = [ "${aws_security_group.cluster_security_group.id}" ]    # network group
  key_name = "${var.keypair_name}"                                                  # keypair configured service by amazon


  provisioner "file" {
    source = "resources/api/api.js"
    destination = "/home/ubuntu/api.js"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }


  provisioner "file" {
    source = "resources/api/package.json"
    destination = "/home/ubuntu/package.json"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }


  provisioner "file" {
    source = "resources/api/install_api.sh"
    destination = "/home/ubuntu/install_api.sh"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }


  provisioner "file" {
    source = "resources/test/locustfile.py"
    destination = "/home/ubuntu/locustfile.py"

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }


  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/install_api.sh",
      "PGHOST=${aws_lb.coordinators.dns_name} /home/ubuntu/install_api.sh"
    ]

    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("resources/${var.keypair_name}.pem")}"
    }
  }

  provisioner "remote-exec" {
    scripts = [
      "resources/test/install_locust.sh"
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
  vpc_id = "${data.aws_vpc.default.id}"

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
