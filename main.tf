resource "aws_key_pair" "keyfile" {
    
  key_name   = "keyfile"
  public_key = file("keyfile.pub")
  tags       = {
  Name = "keyfile"
  }
}

data "aws_availability_zones" "az" {

state = "available"

}

resource "aws_vpc" "vpc01"{

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
  	  Name = "${var.project_name}-vpc"
 }

}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc01.id
  tags = {
           Name = "${var.project_name}-igw"
  }
}




resource "aws_subnet" "pub1" {
    
  vpc_id = aws_vpc.vpc01.id
  map_public_ip_on_launch = true
  cidr_block = cidrsubnet(var.vpc_cidr , var.subnet_bit , 0)
  availability_zone = data.aws_availability_zones.az.names[0] 
  tags = {
       	  Name = "${var.project_name}-pub1"
 }  
}


resource "aws_subnet" "pub2" {

  vpc_id = aws_vpc.vpc01.id
  map_public_ip_on_launch = true
  cidr_block = cidrsubnet(var.vpc_cidr , var.subnet_bit , 1)
  availability_zone = data.aws_availability_zones.az.names[1]
  tags = {
          Name = "${var.project_name}-pub2"
 }
}



resource "aws_subnet" "pri1" {

  vpc_id = aws_vpc.vpc01.id
  map_public_ip_on_launch = true
  cidr_block = cidrsubnet(var.vpc_cidr , var.subnet_bit , 2)
  availability_zone = data.aws_availability_zones.az.names[0]
  tags = {
          Name = "${var.project_name}-pri1"
 }
}


resource "aws_subnet" "pri2" {

  vpc_id = aws_vpc.vpc01.id
  map_public_ip_on_launch = true
  cidr_block = cidrsubnet(var.vpc_cidr , var.subnet_bit , 3)
  availability_zone = data.aws_availability_zones.az.names[1]
  tags = {
          Name = "${var.project_name}-pri2"
 }
}


resource "aws_route_table" "rt_public" {

  vpc_id= aws_vpc.vpc01.id
  route {
       	cidr_block = "0.0.0.0/0"
    	gateway_id = aws_internet_gateway.igw.id
       }
  	tags = {
  		Name = "${var.project_name}-public-rt"
 }
}


resource "aws_route_table_association" "public_asso1" {        

  subnet_id      = aws_subnet.pub1.id
  route_table_id = aws_route_table.rt_public.id
}


resource "aws_route_table_association" "public_asso2" {

  subnet_id      = aws_subnet.pub2.id
  route_table_id = aws_route_table.rt_public.id
}


resource "aws_eip" "elastic_ip" {
  vpc      = true
  tags     = {
              Name = "${var.project_name}-elastic-ip"
 }
}


resource "aws_nat_gateway" "natgw" {

  allocation_id = aws_eip.elastic_ip.id
  subnet_id     = aws_subnet.pub1.id
  tags = {
      	  Name = "${var.project_name}-natgateway"
 }
}



resource "aws_route_table" "rt_private" {

  vpc_id = aws_vpc.vpc01.id
  route {
 	 cidr_block = "0.0.0.0/0"
 	 nat_gateway_id = aws_nat_gateway.natgw.id
       }
  tags = {
  Name = "${var.project_name}-private"
 }
}


resource "aws_route_table_association" "private_asso1" {        

  subnet_id      = aws_subnet.pri1.id
  route_table_id = aws_route_table.rt_private.id
}


resource "aws_route_table_association" "private_asso2" {      
  subnet_id      = aws_subnet.pri2.id
  route_table_id = aws_route_table.rt_private.id
}


resource "aws_security_group" "bastion" {
  
  name        = "${var.project_name}-bastion"
  description = "bastion server"
  vpc_id      =  aws_vpc.vpc01.id

  ingress  { 
    
      from_port        = 22 
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  

  egress  {

      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  

  tags = {
    Name = "${var.project_name}-bastion-sec"
  }
}


resource "aws_security_group" "webserver" {

  name        = "${var.project_name}-webserver"
  description = "allows 22 from bastion and 80,443 from outside"
  vpc_id      =  aws_vpc.vpc01.id

  ingress  {

      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

  ingress  {

      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

  ingress  {

      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      security_groups  = [aws_security_group.bastion.id]
    }

  egress  {

      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }


  tags = {
    Name = "${var.project_name}-webserver-sec"
  }
}


resource "aws_security_group" "database" {

  name        = "${var.project_name}-database"
  description = "3306 from webserver and 22 from bastian"
  vpc_id      =  aws_vpc.vpc01.id

  ingress  {

      from_port        = 3306
      to_port          = 3306
      protocol         = "tcp"
      security_groups  = [aws_security_group.webserver.id]
    }

   ingress  {

      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      security_groups  = [aws_security_group.bastion.id]
    }
  egress  {

      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }


  tags = {
    Name = "${var.project_name}-database-sec"
  }
}




resource "aws_instance" "bastion-instance" {
  ami                         = var.ami
  instance_type               = var.type
  subnet_id                   = aws_subnet.pub1.id
  key_name                    = aws_key_pair.keyfile.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  tags = {
    Name = "${var.project_name}-bastionserver"
  }
}

resource "aws_instance" "webserver-instance" {
  ami                         = var.ami
  instance_type               = var.type
  subnet_id                   = aws_subnet.pub2.id
  key_name                    = aws_key_pair.keyfile.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.webserver.id]
  tags = {
    Name = "${var.project_name}-webserver"
  }
}

resource "aws_instance" "database-instance" {
  ami                         = var.ami
  instance_type               = var.type
  subnet_id                   = aws_subnet.pri1.id
  key_name                    = aws_key_pair.keyfile.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.database.id]
  tags = {
    Name = "${var.project_name}-database"
  }
}
