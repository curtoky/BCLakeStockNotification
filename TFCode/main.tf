provider "aws" {
  region = "us-east-1"
 default_tags {
   tags = {
     Environment = "Production"
     Owner       = "Curtis W"
     Project     = "Fisher Info"
   }
 }
}

#######
##IAM##
#######

resource "aws_iam_policy" "iam_policy_for_lambda" {
 name         = "iam_policy_for_lambda"
 path         = "/"
 description  = "AWS IAM Policy for managing aws lambda role"
 policy       = "${file("../JSON/IAM_Policy.json")}"
}


resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_role_for_lambda"
  assume_role_policy = "${file("../JSON/IAM_Role.json")}"
}


resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
 role        = aws_iam_role.iam_for_lambda.name
 policy_arn  = aws_iam_policy.iam_policy_for_lambda.arn
}


resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = "${file("../JSON/IAM_Role_ECS.json")}"
}


data "aws_iam_policy" "ecs_task_execution_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy_attachment" {
  role       = "${aws_iam_role.ecs_task_execution_role.name}"
  policy_arn = "${data.aws_iam_policy.ecs_task_execution_policy.arn}"
}

###################
##LAMBDA FUNCTION##
###################

resource "aws_lambda_function" "SMS_notification" {
  filename      = "../Python/SMS.zip"
  function_name = var.lambda_function_name
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
}


##################
##DYNAMODB TABLE##
##################

resource "aws_dynamodb_table" "dynamo_fisherInfo" { 
   name           = var.dynamodb_table_name
   read_capacity  = var.dynamodb_table_capacity
   write_capacity = var.dynamodb_table_capacity
   
   attribute { 
      name        = var.dynamodb_hash_key
      type        = "S" 
   }
   
   hash_key       = var.dynamodb_hash_key
   point_in_time_recovery { enabled = true } 
   server_side_encryption { enabled = true } 
} 


###########
####VPC####
###########

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}


resource "aws_subnet" "subnet_internal_1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}


resource "aws_subnet" "subnet_internal_2" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1c"
}


resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}


resource "aws_route_table_association" "route_association_1" {
  subnet_id      = aws_subnet.subnet_internal_1.id
  route_table_id = aws_route_table.route_table.id
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}


resource "aws_route_table_association" "route_association_2" {
  subnet_id      = aws_subnet.subnet_internal_2.id
  route_table_id = aws_route_table.route_table.id
}


resource "aws_vpc_endpoint" "vpc_endpoint_ecr_docker" {
  vpc_id             = "${aws_vpc.vpc.id}"
  service_name       = "${var.service_prefix}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.subnet_internal_1.id, aws_subnet.subnet_internal_2.id]
  security_group_ids = ["${aws_security_group.sg_lb.id}"]

  private_dns_enabled = true
}


resource "aws_vpc_endpoint" "vpc_endpoint_s3" {
  vpc_id            = "${aws_vpc.vpc.id}"
  service_name      = "${var.service_prefix}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.route_table.id]
  
}


resource "aws_vpc_endpoint" "vpc_endpoint_dynamodb" {
  vpc_id            = "${aws_vpc.vpc.id}"
  service_name      = "${var.service_prefix}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.route_table.id]
  
}


resource "aws_vpc_endpoint" "vpc_endpoint_ecr_api" {
  vpc_id              = "${aws_vpc.vpc.id}"
  service_name        = "${var.service_prefix}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_internal_1.id, aws_subnet.subnet_internal_2.id]
  security_group_ids  = ["${aws_security_group.sg_lb.id}"]

  private_dns_enabled = true
}


###############
##ECS CLUSTER##
###############

resource "aws_ecs_cluster" "ecs_cluster_flask_app" {
  name    = "Flask-App"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}


resource "aws_ecs_service" "ecs_service_flask_app" {
    name                 = "web"
    cluster              = aws_ecs_cluster.ecs_cluster_flask_app.id
    task_definition      = aws_ecs_task_definition.td_ecs_flask_app.arn
    desired_count        = 1
    launch_type          = "FARGATE"
    network_configuration {
        subnets          = [aws_subnet.subnet_internal_1.id, aws_subnet.subnet_internal_2.id]
        assign_public_ip = false
        security_groups  = [aws_security_group.sg_flask.id]
    }
    
    load_balancer {
    target_group_arn     = aws_lb_target_group.lb_tg.arn
    container_name       = "Flask"
    container_port       = var.flask_port
  } 
    
}


resource "aws_ecs_task_definition" "td_ecs_flask_app" {
  family                   = "main"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = <<TASK_DEFINITION
[
  {
    "name": "Flask",
    "image": "${var.ecs_image_url}",
    "cpu": 512,
    "memory": 1024,
    "essential": true,
    "portMappings": [
     {
      "containerPort": 5000,
      "hostPort": 5000
     }]
  }
]
TASK_DEFINITION

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}


#############
#####ALB#####
#############

resource "aws_lb_target_group" "lb_tg" {
  port        = var.flask_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"
}


resource "aws_lb" "lb" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_lb.id]
  subnets            = [aws_subnet.subnet_internal_1.id, aws_subnet.subnet_internal_2.id]

  enable_deletion_protection = true
}


resource "aws_lb_listener" "front_end" {
  load_balancer_arn  = aws_lb.lb.arn
  port               = var.http_port
  protocol           = "HTTP"
 
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg.arn
  }
}


#################
#SECURITY GROUPS#
#################

resource "aws_security_group" "sg_lb" {
  description        = "Allow HTTP/S Inbound Traffic"
  vpc_id             = aws_vpc.vpc.id
       
  ingress {
    description      = "HTTP from Internet"
    from_port        = var.http_port
    to_port          = var.http_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTPS from Internet"
    from_port        = var.https_port
    to_port          = var.https_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    description      = "all outbound"
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    from_port        = 0
    to_port          = 0
  }
}


resource "aws_security_group" "sg_flask" {
  description        = "Allow TCP 5000 Inbound Traffic"
  vpc_id             = aws_vpc.vpc.id
       
  ingress {
    description      = "TCP5000 from VPC"
    from_port        = var.flask_port
    to_port          = var.flask_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    description      = "all outbound"
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    from_port        = 0
    to_port          = 0
  }
}


##################
###EVENT BRIDGE###
##################

resource "aws_cloudwatch_event_rule" "nightly_at_5pm" {
  name                = "every-night-5pm"
  description         = "Fires every night at 5pm"
  schedule_expression = "cron(0 0 * * ? *)"
}


resource "aws_cloudwatch_event_target" "allow_cloudwatch_to_SNS" {
  rule      = "${aws_cloudwatch_event_rule.nightly_at_5pm.name}"
  target_id = "lambda"
  arn       = "${aws_lambda_function.SMS_notification.arn}"
}


resource "aws_lambda_permission" "allow_cloudwatch_to_SNS" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.SMS_notification.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.nightly_at_5pm.arn}"
}
