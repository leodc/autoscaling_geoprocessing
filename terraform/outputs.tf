output "public_ip_gtm" {
 value = "${aws_instance.gtm.public_ip}"
}

# output "coordinators_load_balancer" {
#  value = "${aws_elb.coordinators.dns_name}"
# }


output "monitor_public_ip" {
 value = "${aws_instance.monitor.public_ip}"
}

output "api_public_ip" {
value = "${aws_instance.api.public_ip}"
}
