############################################
#  Key pair (already created in AWS console)
############################################
data "aws_key_pair" "existing" {
  key_name = var.key_pair_name
}

############################################
#  Security Group
############################################
resource "aws_security_group" "ci_sg" {
  name        = "akash-ci-sg"
  description = "Allow SSH, Jenkins (8080) and SonarQube (9000)"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SonarQube"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "akash-ci-sg"
  }
}

############################################
#  IAM role so Jenkins can deploy to EB + S3
############################################
data "aws_iam_policy_document" "jenkins_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "akash-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume.json
}

resource "aws_iam_role_policy_attachment" "eb_full" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-AWSElasticBeanstalk"
}

resource "aws_iam_role_policy_attachment" "s3_rw" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "akash-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

############################################
#  Latest Amazon Linux 2023 AMI
############################################
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

############################################
#  EC2 instance with Jenkins + SonarQube
############################################
resource "aws_instance" "ci_server" {
  ami           = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type
  key_name      = data.aws_key_pair.existing.key_name

  vpc_security_group_ids = [aws_security_group.ci_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  user_data = <<-EOF
  #!/bin/bash
  set -eux

  dnf update -y
  dnf install -y git fontconfig java-21-amazon-corretto-headless

  # Docker
  dnf install -y docker
  systemctl enable --now docker
  usermod -aG docker ec2-user

  # Jenkins repo + install
  curl -fsSL https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key |
      tee /etc/pki/rpm-gpg/RPM-GPG-KEY-jenkins.io
  curl -fsSL https://pkg.jenkins.io/redhat-stable/jenkins.repo |
      tee /etc/yum.repos.d/jenkins.repo
  dnf install -y jenkins
  systemctl enable --now jenkins

  # SonarQube container
  mkdir -p /opt/sonardata/{data,extensions,logs}
  docker run -d --name sonarqube \
    -p 9000:9000 \
    -v /opt/sonardata/data:/opt/sonarqube/data \
    -v /opt/sonardata/extensions:/opt/sonarqube/extensions \
    -v /opt/sonardata/logs:/opt/sonarqube/logs \
    sonarqube:10.5-community
EOF


  tags = {
    Name = "akash-ci-server"
  }
}

############################################
#  S3 bucket to store EB bundles
############################################
resource "aws_s3_bucket" "artifact_store" {
  bucket        = "${var.eb_app_name}-artifacts"
  force_destroy = true
  tags          = { Name = "${var.eb_app_name}-artifacts" }
}

############################################
#  Elastic Beanstalk: app + environment
############################################
resource "aws_elastic_beanstalk_application" "app" {
  name = var.eb_app_name
}

resource "aws_elastic_beanstalk_environment" "env" {
  name                = var.eb_env_name
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.5.2 running Corretto 21" # latest AL2023 + JDK 21

  # Attach IAM instance profile to EB EC2s
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.jenkins.name
  }

  # Make Java aware of cgroup limits
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "JAVA_TOOL_OPTIONS"
    value     = "-XX:+UseContainerSupport"
  }
}
