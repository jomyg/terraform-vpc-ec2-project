# Creating a VPC and launching EC2 instances in AWS using Terraform

[![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)]()

## Description:

This is a terraform-aws project which deals with creating a VPC having 4 Subnets: 2 Private and 2 Public, 1 NAT Gateways, 1 Internet Gateway, and 2 Route Tables. 
I'm also going to spin up EC2 instances inside the VPC. Two instances will be in the public subnet, where 1 could be used as a webserver and the other as a bastion server for secured access.
The EC2 instance for database will be created in the private subnet for improved security. The remaining 1 private subnet can be used for creating a database replica in future if there occurs any requirement.



## Pre-requisites:

1) AWS IAM account with policies attached for creating a VPC. In otherway, you can also use/attach a IAM Role for the terraform running server for the below code setup.
2) Basic knowledge about AWS services especially VPC, EC2 and IP Subnetting.
3) Terraform installed. 
> Click here to [download](https://www.terraform.io/downloads.html) and  [install](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/aws-get-started) terraform.

Installation steps I followed:
```sh
wget https://releases.hashicorp.com/terraform/0.15.3/terraform_0.15.3_linux_amd64.zip
unzip terraform_0.15.3_linux_amd64.zip 
ls 
terraform  terraform_0.15.3_linux_amd64.zip    
mv terraform /usr/bin/
which terraform 
/usr/bin/terraform
```
All of these will be created by simply running a terraform code which I created.


> Terraform is a tool for building, changing, and versioning infrastructure safely and efficiently. Terraform can help with multi-cloud by having one workflow for all clouds. The infrastructure Terraform manages can be hosted on public clouds like Amazon Web Services, Microsoft Azure, and Google Cloud Platform, or on-prem in private clouds such as VMWare vSphere, OpenStack, or CloudStack. Terraform treats infrastructure as code (IaC) so you never have to worry about you infrastructure drifting away from its desired configuration.

## Steps:

##### 1) Creating the variables.tf file

This file is used to declare the variables we are using in this project. The value of these variables are given later in terraform. tfvars file

```sh
variable "region" {}

variable "access_key"{}

variable "secret_key"{}

variable "project_name" {}

variable "vpc_cidr" {}

variable "subnet_bit" {}

variable "ami" {}

variable "type" {}
```

##### 2) Creating the provider.tf file

This files contains the provider configuration.
```sh
provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}
```

##### 3) Creating the terraform. tfvars

The file is used to automatically load the variable definitions in it.
```sh
region       = "Region-of-project"
project_name = "name-of-your-project"
vpc_cidr     = "your-cidr-block"
subnet_bit   = "x"
ami          = "ami-id"
type         = "type of instance"
access_key = "access-key-of-AWS-IAM-user"
secret_key = "secret-key-of-AWS-IAM-user"
```
Here, I'm using the following values
```sh
region       = "us-east-2"
project_name = "my-project"
vpc_cidr     = "172.31.0.0/16"
subnet_bit   = "2"                              #####as I'm subnetting into 4  
ami          = "ami-0443305dabd4be2bc"          
type         = "t2.micro"
access_key = "xxxxxxxxxxxxxxxx"
secret_key = "xxxxxxxxxxxxxxxxxxxxxx"
```

Enter the command given below to initialize a working directory containing Terraform configuration files. This is the first command that should be run after writing a new Terraform configuration.
```sh
terraform init
```
Now a terraform. tfstate file would be generated here.

##### 4) Creating the main .tf file

The main configuration file has the following contents:

> To create VPC

```sh
resource "aws_vpc" "vpc01"{

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
          Name = "${var.project_name}-vpc"
 }

}
```


> To list the  AWS Availability Zones which can be accessed by an AWS account within the region configured.

```sh
data "aws_availability_zones" "az" {

state = "available"

}
```
> To create Internet GateWay For the VPC
```sh
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc01.id
  tags = {
           Name = "${var.project_name}-igw"
  }
}
```

Next I'm going to create 2 public subnets and 2 private subnets. Hence I'm going to divide the entire IP range into 4 equal subnets. For this, I'm using the [cidrsubnet function](https://www.terraform.io/docs/language/functions/cidrsubnet.html) in terraform.

> creating public subnets
```sh
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

```
> creating private subnets
```sh
resource "aws_subnet" "pri1" {

  vpc_id = aws_vpc.vpc01.id
  cidr_block = cidrsubnet(var.vpc_cidr , var.subnet_bit , 2)
  availability_zone = data.aws_availability_zones.az.names[0]
  tags = {
          Name = "${var.project_name}-pri1"
 }
}


resource "aws_subnet" "pri2" {

  vpc_id = aws_vpc.vpc01.id
  cidr_block = cidrsubnet(var.vpc_cidr , var.subnet_bit , 3)
  availability_zone = data.aws_availability_zones.az.names[1]
  tags = {
          Name = "${var.project_name}-pri2"
 }
}

```

> Creating an Elastic IP 

```sh
resource "aws_eip" "elastic_ip" {
  vpc      = true
  tags     = {
              Name = "${var.project_name}-elastic-ip"
 }
}
```
> Creating a NAT-Gateway for the private subnet in VPC.

The elastic IP is attached to the NAT Gateway upon creation.
```sh
resource "aws_nat_gateway" "natgw" {

  allocation_id = aws_eip.elastic_ip.id
  subnet_id     = aws_subnet.pub1.id
  tags = {
          Name = "${var.project_name}-natgateway"
 }
}
```

> Creating Public Route Table

```sh
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
```
> Creating Public Route Table Association
```sh
resource "aws_route_table_association" "public_asso1" {

  subnet_id      = aws_subnet.pub1.id
  route_table_id = aws_route_table.rt_public.id
}


resource "aws_route_table_association" "public_asso2" {

  subnet_id      = aws_subnet.pub2.id
  route_table_id = aws_route_table.rt_public.id
}

```

> Creating Private Route Table
```sh
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
```

> Creating Private Route Table Association
```sh
resource "aws_route_table_association" "private_asso1" {

  subnet_id      = aws_subnet.pri1.id
  route_table_id = aws_route_table.rt_private.id
}


resource "aws_route_table_association" "private_asso2" {
  subnet_id      = aws_subnet.pri2.id
  route_table_id = aws_route_table.rt_private.id
}
```

Now , the VPC named 'my-project-vpc' with 2 public subnets and 2 private subnets have been created. Next, we are going to create 2 EC2 instances in public subnet and 1 in private subnet.

> Creating key pair

Let us start with the creation of key pair . I have already generated a key pair using the  ssh-keygen command and saved the public key in 'keyfile.pub'.
```sh
resource "aws_key_pair" "keyfile" {

  key_name   = "keyfile"
  public_key = file("keyfile.pub")
  tags       = {
  Name = "keyfile"
  }
}
```

> Security group for bastion server
```sh
resource "aws_security_group" "bastion" {

  name        = "${var.project_name}-bastion"
  description = "Inbound from 22"
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
```
> Security group for webserver
```sh
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
```

> Security group for database
```sh
resource "aws_security_group" "database" {

  name        = "${var.project_name}-database"
  description = "3306 from webserver and 22 from bastion server"
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
```
> Creating an EC2 instance for bastion host
```sh
resource "aws_instance" "bastion-instance" {
  ami                         = var.ami
  instance_type               = var.type
  subnet_id                   = aws_subnet.pub1.id
  key_name                    = aws_key_pair.keyfile.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  tags = {
    Name = "${var.project_name}-bastion-host"
  }
}
```
> Creating an EC2 instance for webserver
```sh
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
```
> Creating an EC2 instance for database
```sh
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
```

Now, inorder to validate the terraform files, run the following command:
```sh
terraform validate
```
Now, inorder to create and verify the execution plan, run the following command: 
```sh
terraform plan
```
Now, let us executes the actions proposed in a Terraform plan by using the following command:
```sh
terraform apply
```

## Conclusion:

I have created a VPC with 2 public and 2 private subnets and 3 EC2s with proper security groups and keypair using terraform. 

