# jenkins.tf

# =============================================================================
# Jenkins Security & Load Balancer
# =============================================================================

# ALB용 보안 그룹 (인터넷에서 HTTP:80 포트만 허용)
resource "aws_security_group" "alb_sg" {
  count = var.create_jenkins_server ? 1 : 0
  
  name_prefix = "${var.project_name}-jenkins-alb-sg-"
  vpc_id      = module.vpc_app.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP access from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-jenkins-alb-sg"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# 젠킨스 EC2 인스턴스용 보안 그룹 (ALB에서만 8080 포트 허용)
resource "aws_security_group" "jenkins_sg" {
  count = var.create_jenkins_server ? 1 : 0
  
  name_prefix = "${var.project_name}-jenkins-ec2-sg-"
  vpc_id      = module.vpc_app.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg[0].id]
    description     = "Allow Jenkins access only from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.project_name}-jenkins-ec2-sg"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# Application Load Balancer (ALB)
resource "aws_lb" "jenkins_alb" {
  count = var.create_jenkins_server ? 1 : 0
  
  name               = "${var.project_name}-jenkins-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg[0].id]
  subnets            = module.vpc_app.public_subnets # 퍼블릭 서브넷에 생성

  tags = {
    Name        = "${var.project_name}-Jenkins-ALB"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# ALB Target Group (젠킨스 인스턴스를 가리킴)
resource "aws_lb_target_group" "jenkins_tg" {
  count = var.create_jenkins_server ? 1 : 0
  
  name     = "${var.project_name}-jenkins-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc_app.vpc_id

  health_check {
    path                = "/login"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-jenkins-tg"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# ALB Listener (HTTP:80 요청을 Target Group으로 전달)
resource "aws_lb_listener" "jenkins_listener" {
  count = var.create_jenkins_server ? 1 : 0
  
  load_balancer_arn = aws_lb.jenkins_alb[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_tg[0].arn
  }
}

# =============================================================================
# Jenkins Controller EC2 Instance
# =============================================================================

resource "aws_instance" "jenkins_controller" {
  count = var.create_jenkins_server ? 1 : 0
  
  ami           = var.jenkins_ami_id
  instance_type = var.jenkins_instance_type

  # 프라이빗 서브넷에 생성하고 퍼블릭 IP는 할당하지 않음
  subnet_id                   = module.vpc_app.private_subnets[0]
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.jenkins_sg[0].id]

  # iam.tf에서 생성한 인스턴스 프로파일을 연결
  iam_instance_profile = aws_iam_instance_profile.jenkins_instance_profile[0].name

  # EC2 부팅 시 젠킨스를 설치하는 스크립트 (Amazon Linux 2023)
  user_data = <<-EOF
              #!/bin/bash
              sudo dnf update -y
              sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
              sudo dnf upgrade -y
              sudo dnf install java-17-amazon-corretto -y
              sudo dnf install jenkins -y
              sudo systemctl enable jenkins
              sudo systemctl start jenkins
              sudo dnf install -y git
              EOF

  root_block_device {
    volume_type = "gp3"
    volume_size = var.jenkins_volume_size
    encrypted   = true
  }

  tags = {
    Name        = "${var.project_name}-Jenkins-Controller"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# 젠킨스 인스턴스를 ALB Target Group에 연결
resource "aws_lb_target_group_attachment" "jenkins_attachment" {
  count = var.create_jenkins_server ? 1 : 0
  
  target_group_arn = aws_lb_target_group.jenkins_tg[0].arn
  target_id        = aws_instance.jenkins_controller[0].id
  port             = 8080
}

