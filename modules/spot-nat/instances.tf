
resource "aws_launch_template" "nat" {
  name_prefix = "${var.name}-"
  image_id    = var.ami_id

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20 # Size of the EBS volume in GB
      delete_on_termination = true
      volume_type           = "gp2" # Change volume type as needed
    }
  }

  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    security_groups             = [aws_security_group.nat.id]
  }

  monitoring {
    enabled = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.nat.name
  }

  metadata_options {
    http_tokens = "required"
  }

  instance_type                        = var.instance_types[0]
  key_name                             = var.key_name
  instance_initiated_shutdown_behavior = "terminate"
  user_data                            = filebase64("${path.module}/scripts/startup.sh")
}

resource "aws_autoscaling_group" "nat" {
  count               = length(var.vpc_info)
  name                = "${var.name}-${count.index}"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = var.vpc_info[count.index].public_subnet_ids

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "price-capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.nat.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type = override.value
        }
      }
    }
  }
  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }
  tag {
    key                 = "yacc:nat:instance"
    value               = "owned"
    propagate_at_launch = true
  }
  tag {
    key                 = "yacc:nat:instance:route:tables"
    value               = jsonencode(var.vpc_info[count.index].route_table_ids)
    propagate_at_launch = true
  }
  tag {
    key                 = "yacc:nat:instance:route:eip"
    value               = var.vpc_info[count.index].elastic_ip_address
    propagate_at_launch = true
  }
  tag {
    key                 = "yacc:nat:instance:route:nat:gw"
    value               = var.vpc_info[count.index].nat_gateway_id
    propagate_at_launch = true
  }
  tag {
    key                 = "yacc:nat:instance:asg:name"
    value               = "${var.name}-${count.index}"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "nat" {
  name        = var.name
  description = "Allow Nat traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "NAT Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.vpc_cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = var.name
  }
}

resource "aws_iam_role" "nat" {
  name = "${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : ["sts:AssumeRole"]
      },
    ]
  })

  inline_policy {
    name = "${var.name}-policy"
    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : ["ec2:ModifyInstanceAttribute"],
          "Resource" : "*"
        }
      ]
    })
  }

  tags = {
    Name = var.name
  }
}

resource "aws_iam_instance_profile" "nat" {
  name = var.name
  role = aws_iam_role.nat.name
}
