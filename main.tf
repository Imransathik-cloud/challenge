# Specify the AWS provider
provider "aws" {
  region = "ap-south-1" # Replace with your preferred AWS region
}

# Use existing VPC and Subnet
variable "existing_vpc_id" {}
variable "existing_subnet_id" {}
variable "my_ip" {}

# Security Group for EC2
resource "aws_security_group" "example_sg" {
  vpc_id = var.existing_vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "TerraformSecurityGroup"
  }
}

# IAM Role for EC2
resource "aws_iam_role" "example_iam_role" {
  name               = "terraformprojectrole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy for EC2 to access specific S3 bucket
resource "aws_iam_policy" "s3_access_policy" {
  name        = "S3AccessPolicy"
  description = "Policy to allow EC2 to read and write to a specific S3 bucket"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "arn:aws:s3:::terraformproject-bucket",
          "arn:aws:s3:::terraformproject-bucket/*"
        ]
      }
    ]
  })
}

# Attach S3 Access Policy to IAM Role
resource "aws_iam_role_policy_attachment" "example_role_s3_attachment" {
  role       = aws_iam_role.example_iam_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Create an IAM Instance Profile
resource "aws_iam_instance_profile" "example_instance_profile" {
  name = "EC2InstanceProfile"
  role = aws_iam_role.example_iam_role.name
}

# S3 Bucket
resource "aws_s3_bucket" "example_bucket" {
  bucket = "terraformproject-bucket"
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.example_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# EC2 Instance
resource "aws_instance" "example_instance" {
  ami           = "ami-0b7207e48d1b6c06f" # Replace with a valid AMI ID for your region
  instance_type = "t2.micro"
  subnet_id     = var.existing_subnet_id

  # Attach the IAM Instance Profile
  iam_instance_profile = aws_iam_instance_profile.example_instance_profile.name

  # Attach the Security Group
  vpc_security_group_ids = [aws_security_group.example_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y aws-cli
              aws s3 ls s3://terraformproject-bucket > /tmp/s3_list.txt
              echo "Test file upload" > /tmp/test.txt
              aws s3 cp /tmp/test.txt s3://terraformproject-bucket/
              EOF

  tags = {
    Name = "TerraformEC2Instance"
  }
}