/*
Output file to highlight customized outputs that are useful
(compared to the hundreds of attributes Terraform stores)

To see the output after the apply, use the command: "terraform output"
 */

 output "public_ip_coordinator" {
   value = "${aws_instance.coordinator.public_ip}"
 }

 output "public_ip_gtm" {
   value = "${aws_instance.gtm.public_ip}"
 }
