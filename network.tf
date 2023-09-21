resource "aws_internet_gateway" "terraform-eks-igw" {
    vpc_id = "${aws_vpc.terraform-eks-vpc.id}"
    tags = {
        Name = "terraform-eks-igw"
    }
}

resource "aws_route_table" "terraform-eks-public-rt-1a" {
    vpc_id = "${aws_vpc.terraform-eks-vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.terraform-eks-igw.id}"
    }
    tags = {
        Name = "terraform-eks-public-rt-1a"
    }
}

resource "aws_route_table" "terraform-eks-public-rt-1b" {
    vpc_id = "${aws_vpc.terraform-eks-vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.terraform-eks-igw.id}"
    }
    tags = {
        Name = "terraform-eks-public-rt-1b"
    }
}

resource "aws_route_table_association" "terraform-eks-rt-public-subnet-association-1a"{
    subnet_id = "${aws_subnet.terraform-eks-subnet-public-1a.id}"
    route_table_id = "${aws_route_table.terraform-eks-public-rt-1a.id}"
}

resource "aws_route_table_association" "terraform-eks-rt-public-subnet-association-1b"{
    subnet_id = "${aws_subnet.terraform-eks-subnet-public-1b.id}"
    route_table_id = "${aws_route_table.terraform-eks-public-rt-1b.id}"
}

resource "aws_route_table" "terraform-eks-private-rt-1a" {
    vpc_id = "${aws_vpc.terraform-eks-vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.terraform-eks-nat-gateway-1a.id}"
    }
    tags = {
        Name = "terraform-eks-private-rt-1a"
    }
}

resource "aws_route_table" "terraform-eks-private-rt-1b" {
    vpc_id = "${aws_vpc.terraform-eks-vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.terraform-eks-nat-gateway-1b.id}"
    }
    tags = {
        Name = "terraform-eks-private-rt-1b"
    }
}
resource "aws_route_table_association" "terraform-eks-rt-private-subnet-association-1a"{
    subnet_id = "${aws_subnet.terraform-eks-subnet-private-1a.id}"
    route_table_id = "${aws_route_table.terraform-eks-private-rt-1a.id}"
}

resource "aws_route_table_association" "terraform-eks-rt-private-subnet-association-1b"{
    subnet_id = "${aws_subnet.terraform-eks-subnet-private-1b.id}"
    route_table_id = "${aws_route_table.terraform-eks-private-rt-1b.id}"
}
resource "aws_eip" "terraform-eks-nat-elastic-ip-1a" {
    vpc = true
    tags = {
        Name = "terraform-eks-nat-elastic-ip-1a"
    }
}

resource "aws_eip" "terraform-eks-nat-elastic-ip-1b" {
    vpc = true
    tags = {
        Name = "terraform-eks-nat-elastic-ip-1b"
    }
}

resource "aws_nat_gateway" "terraform-eks-nat-gateway-1a" {
    connectivity_type = "public"
    allocation_id = aws_eip.terraform-eks-nat-elastic-ip-1a.id
    subnet_id = aws_subnet.terraform-eks-subnet-public-1a.id
    tags = {
        Name = "terraform-eks-nat-gateway-1a"
    }
    depends_on = [
        aws_internet_gateway.terraform-eks-igw,
        aws_eip.terraform-eks-nat-elastic-ip-1a
    ]
}

resource "aws_nat_gateway" "terraform-eks-nat-gateway-1b" {
    connectivity_type = "public"
    allocation_id = aws_eip.terraform-eks-nat-elastic-ip-1b.id
    subnet_id = aws_subnet.terraform-eks-subnet-public-1b.id
    tags = {
        Name = "terraform-eks-nat-gateway-1b"
    }
    depends_on = [
        aws_internet_gateway.terraform-eks-igw,
        aws_eip.terraform-eks-nat-elastic-ip-1a
    ]
}

resource "aws_security_group" "terraform-eks-sg" {
    vpc_id = "${aws_vpc.terraform-eks-vpc.id}"
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "terraform-eks-sg"
    }
}