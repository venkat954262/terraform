provider "aws" {
  region     = "**"
  access_key = "**"
  secret_key = "***"
}


##create VPC###

resource "aws_vpc" "terraform-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "terraform-demo-vpc"
  }

}

output "aws_vpc_id" {
  value = "${aws_vpc.terraform-vpc.id}"
}

##create security group##
resource "aws_security_group" "terraform-private-sg"{
  description = "Allow limited inbound external traffic"
  vpc_id = "${aws_vpc.terraform-vpc.id}"
  name = "terraform_ec2_private_sg"
  
 ingress{
   protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
   from_port = "22"
   to_port = "22"
}

ingress{
  protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
   from_port = "8080"
   to_port = "8080"
}

ingress{
  protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
   from_port = "443"
   to_port = "443"
}

egress{
  protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
   from_port = "0"
   to_port = "0"
}

tags = {
  Name = "ec2-private-sg"
}

}

output "aws_security_gr_id" {
    value = "${aws_security_group.terraform-private-sg.id}"
}


##Create SUBNETS##
resource "aws_subnet" "terraform-subnet_1" {
  vpc_id     = "${aws_vpc.terraform-vpc.id}"
  cidr_block = "10.0.20.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "terraform-subnet_1"
  }
}

output "aws_subnet_subnet_1" {
  value = "${aws_subnet.terraform-subnet_1.id}"
}


resource "aws_subnet" "terraform-subnet_2" {
  vpc_id     = "${aws_vpc.terraform-vpc.id}"
  cidr_block = "10.0.30.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "terraform-subnet_2"
  }
}

output "aws_subnet_subnet_2" {
  value = "${aws_subnet.terraform-subnet_1.id}"
}


##Create EC2##


resource "aws_instance" "terraform_app" {
    ami = "ami-068d43a544160b7ef"
    instance_type = "t2.micro"
    vpc_security_group_ids =  [ "${aws_security_group.terraform-private-sg.id}" ]
    subnet_id = "${aws_subnet.terraform-subnet_1.id}"
    key_name  = "kibana"
    count     = 1
    associate_public_ip_address = true
    tags = {
      Name              = "terraform_ec2_app_awsdev"
      Environment       = "development"
      Project           = "DEMO-TERRAFORM"
    }
}

output "instance_id_list" { 
  value = ["${aws_instance.terraform_app.*.id}"]  
}





