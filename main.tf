resource "aws_vpc" "dev_vpc" {
  cidr_block           = "10.14.0.0/16"
  enable_dns_hostnames = true # As dns hostnames are defaultly disabled (set to false), we have to enable it.
  enable_dns_support   = true # Enables dns support, defaultly it is enabled but were adding it explicitly.

  tags = {
    "terraform-project" = "Terraform Projects" # adding this key to track resources used in the project.
  }
}

resource "aws_subnet" "dev_public_subnet" {
  vpc_id                  = aws_vpc.dev_vpc.id # as aws_vpc.dev_vpc is another resource we don't have to qoute it (""). 
  cidr_block              = "10.14.1.0/24"     # as this block is one of the subnets within 10.14.0.0/16
  map_public_ip_on_launch = true               # It'll ensure whenerver we launch an instance it'll have a public ip address.
  availability_zone       = "ap-south-1a"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "dev_internet_gateway" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "dev-public-rt" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "dev-public-rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.dev-public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.dev_internet_gateway.id
}

resource "aws_route_table_association" "dev_public_assoc" {
  subnet_id      = aws_subnet.dev_public_subnet.id
  route_table_id = aws_route_table.dev-public-rt.id
}

resource "aws_security_group" "dev_sg" {
  name        = "dev_sg" # the security group resource have a attribute "name" so we dont have to tag it(but we can also tag it).
  description = "dev security group"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "dev_auth" {
  key_name   = "devkey"
  public_key = file("~/.ssh/devkey.pub")
}

resource "aws_instance" "dev_node" {
  instance_type = "t2.micro"
  ami           = data.aws_ami.server_ami.id

  key_name               = aws_key_pair.dev_auth.id
  vpc_security_group_ids = [aws_security_group.dev_sg.id]
  subnet_id              = aws_subnet.dev_public_subnet.id
  user_data = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname = self.public_ip,
      user = "ubuntu",
      identityfile = "~/.ssh/devkey"
    })
    interpreter = var.host_os == "windows" ? [ "Powershell", "-Command" ] : ["bash", "-c"]
  }
}