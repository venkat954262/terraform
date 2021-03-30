provider "aws" {
  region     = "us-west-2"
  access_key = "***"
  secret_key = "**"
}

variable "region" {
  default = "us-west-2"
}

variable "service_name" {
  default = "demo-service"
}

locals {
  public_subnets = {
    "${var.region}a" = "10.10.101.0/24"
    "${var.region}b" = "10.10.102.0/24"
    "${var.region}c" = "10.10.103.0/24"
  }
  private_subnets = {
    "${var.region}a" = "10.10.201.0/24"
    "${var.region}b" = "10.10.202.0/24"
    "${var.region}c" = "10.10.203.0/24"
  }
}

#####--CREATING VPC--##########################
resource "aws_vpc" "this" {
  cidr_block = "10.10.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.service_name}-vpc"
  }
}

#####--CREATING IGW--##########################
resource "aws_internet_gateway" "this" {
  vpc_id = "${aws_vpc.this.id}"

  tags = {
    Name = "${var.service_name}-internet-gateway"
  }
}

###########--CREATING PUBLIC SUBNETS USING LOCALS & VARIABLES--#################################
resource "aws_subnet" "public" {
  count      = "${length(local.public_subnets)}"
  cidr_block = "${element(values(local.public_subnets), count.index)}"
  vpc_id     = "${aws_vpc.this.id}"

  map_public_ip_on_launch = true
  availability_zone       = "${element(keys(local.public_subnets), count.index)}"

  tags = {
    Name = "${var.service_name}-service-public"
  }
}

###########--CREATING PRIVATE SUBNETS USING LOCALS & VARIABLES--#################################
resource "aws_subnet" "private" {
  count      = "${length(local.private_subnets)}"
  cidr_block = "${element(values(local.private_subnets), count.index)}"
  vpc_id     = "${aws_vpc.this.id}"

  map_public_ip_on_launch = true
  availability_zone       = "${element(keys(local.private_subnets), count.index)}"

  tags = {
    Name = "${var.service_name}-service-private"
  }
}

###########--CREATING DEFAULT ROUTE TABLE--#################################

resource "aws_default_route_table" "public" {
  default_route_table_id = "${aws_vpc.this.main_route_table_id}"

  tags = {
    Name = "${var.service_name}-public"
  }
}
###########--CREATING PUBLIC INTERNET GW--#################################

resource "aws_route" "public_internet_gateway" {
  count                  = "${length(local.public_subnets)}"
  route_table_id         = "${aws_default_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.this.id}"

  timeouts {
    create = "5m"
  }
}

###########--ASSOCIATE PUBLIC SUBNETS TO ROUTE TABLE--#################################

resource "aws_route_table_association" "public" {
  count          = "${length(local.public_subnets)}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_default_route_table.public.id}"
}

###########--ASSOCIATE PRIVATE SUBNETS --#################################

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.this.id}"

  tags = {
    Name = "${var.service_name}-private"
  }
}

resource "aws_route_table_association" "private" {
  count          = "${length(local.private_subnets)}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${aws_route_table.private.id}"
}

###########--CREATE ELASTIC IP & NAT GW --#################################
resource "aws_eip" "nat" {
  vpc = true

  tags = {
    Name = "${var.service_name}-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public.0.id}"

  tags = {
    Name = "${var.service_name}-nat-gw"
  }
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${aws_route_table.private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.this.id}"

  timeouts {
    create = "5m"
  }
}

##create security group##
resource "aws_security_group" "terraform-private-sg"{
  description = "Allow limited inbound external traffic"
  vpc_id = "${aws_vpc.this.id}"
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

    
resource "aws_instance" "web1" {    
    ami = "ami-0518bb0e75d3619ca"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.public.1.id}"
    vpc_security_group_ids =  ["${aws_security_group.terraform-private-sg.id}"]
    key_name  = "demodemo"
    count     = 1
    associate_public_ip_address = true
   
    tags = {
      Name              = "terraform_server-1_awsdev"
      Environment       = "development"
      Project           = "DEMO-TERRAFORM"
    }
}

