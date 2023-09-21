resource "aws_vpc" "terraform-eks-vpc" {
    cidr_block = "10.2.0.0/16"
    enable_dns_hostnames = "true"
    tags = {
        Name = "terraform-eks"
    }
}

resource "aws_subnet" "terraform-eks-subnet-public-1a" {
    vpc_id = "${aws_vpc.terraform-eks-vpc.id}"
    cidr_block = "10.2.1.0/24"
    availability_zone = "eu-north-1a"
    tags = {
        Name = "terraform-eks-subnet-public-1a"
    }
}

resource "aws_subnet" "terraform-eks-subnet-public-1b" {
    vpc_id = "${aws_vpc.terraform-eks-vpc.id}"
    cidr_block = "10.2.2.0/24"
    availability_zone = "eu-north-1b"
    tags = {
        Name = "terraform-eks-subnet-public-1b"
    }
}

resource "aws_subnet" "terraform-eks-subnet-private-1a" {
    vpc_id = "${aws_vpc.terraform-eks-vpc.id}"
    cidr_block = "10.2.3.0/24"
    availability_zone = "eu-north-1a"
    tags = {
        Name = "terraform-eks-subnet-private-1a"
    }
}

resource "aws_subnet" "terraform-eks-subnet-private-1b" {
    vpc_id = "${aws_vpc.terraform-eks-vpc.id}"
    cidr_block = "10.2.4.0/24"
    availability_zone = "eu-north-1b"
    tags = {
        Name = "terraform-eks-subnet-private-1b"
    }
}