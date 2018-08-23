############################################# LOAD BALANCERS
## COORDINATORS
resource "aws_lb" "coordinators" {
  name = "lb-coordinators"

  internal           = false
  load_balancer_type = "network"
  subnets = ["${data.aws_subnet_ids.public.ids}"]

  enable_cross_zone_load_balancing = true

  tags {
    Environment = "production"
  }
}

resource "aws_lb_listener" "coordinators" {
  load_balancer_arn = "${aws_lb.coordinators.arn}"
  port              = "80"
  protocol          = "TCP"

  default_action {
    target_group_arn = "${aws_lb_target_group.coordinators.arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group" "coordinators" {
  name     = "coordinators-target-group"
  protocol = "TCP"
  port     = 30001
  vpc_id      = "${data.aws_vpc.default.id}"
}
