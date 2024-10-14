##Amazon Infrastructure
provider "aws" {
  region = "${var.aws_region}"
}


## Create SSH Key Pair
resource "aws_key_pair" "docker-swarm-key" {
  key_name   = "${var.aws_key_name}"
  public_key = "${file(var.public_key_path)}"
}

## Find latest Ubuntu 20.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}


##Create Swarm Master Instance
resource "aws_instance" "swarm-master" {
  depends_on             = ["aws_security_group.swarm_sg"]
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "${var.aws_instance_size}"
  subnet_id              = aws_subnet.subnet.id
  vpc_security_group_ids = ["${aws_security_group.swarm_sg.id}"]
  key_name               = "${var.aws_key_name}"
  tags = {
    Name = "swarm-master"
  }
}

resource "aws_ebs_volume" "master-ebs" {
  availability_zone = aws_instance.swarm-master.availability_zone
  size              = 2
  tags = {
    Name = "Terraform EBS"
  }
}

resource "aws_volume_attachment" "attach_ebs_master" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.master-ebs.id
  instance_id = aws_instance.swarm-master.id
}

##Create AWS Swarm Workers
resource "aws_instance" "aws-swarm-members" {
  depends_on             = ["aws_security_group.swarm_sg"]
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "${var.aws_instance_size}"
  subnet_id              = aws_subnet.subnet.id
  vpc_security_group_ids = ["${aws_security_group.swarm_sg.id}"]
  key_name               = "${var.aws_key_name}"
  count                  = "${var.aws_worker_count}" 
  tags = {
    Name = "swarm-member-${count.index}"
  }
}

### Prometheus and Grafana

resource "aws_instance" "prometheus" {
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "${var.aws_instance_size}"
  subnet_id              = aws_subnet.subnet.id
  vpc_security_group_ids = ["${aws_security_group.swarm_sg.id}"]
  key_name               = "${var.aws_key_name}"
  tags = {
    Name = "prometheus"
  }
  user_data = filebase64("${path.module}/prometheus/prometheusInstall.sh")
}

resource "aws_instance" "grafana" {
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "${var.aws_instance_size}"
  subnet_id              = aws_subnet.subnet.id
  vpc_security_group_ids = ["${aws_security_group.swarm_sg.id}"]
  key_name               = "${var.aws_key_name}"
  tags = {
    Name = "grafana"
  }
  user_data = filebase64("${path.module}/prometheus/grafanaInstall.sh")
}