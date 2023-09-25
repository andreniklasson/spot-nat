resource "aws_lambda_function" "route_handler" {
  function_name = "${var.name}-route-handler"
  handler       = "handler.lambda_handler"
  role          = aws_iam_role.route_handler.arn
  runtime       = "python3.8"

  filename         = data.archive_file.src_boundle.output_path
  source_code_hash = data.archive_file.src_boundle.output_base64sha256

  timeout     = 20
  memory_size = 128

  architectures = ["x86_64"]
}

data "archive_file" "src_boundle" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/src.zip"
}

resource "aws_iam_role" "route_handler" {
  name = "${var.name}-route-function-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : ["sts:AssumeRole"]
      },
    ]
  })

  inline_policy {
    name = "${var.name}-lambda-policy"
    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "ec2:DescribeInstances",
            "ec2:DescribeTags",
            "ec2:DescribeAddresses",
            "ec2:AllocateAddress",
            "ec2:AssociateAddress",
            "ec2:ReplaceRoute",
            "ec2:DescribeRouteTables",
            "autoscaling:DetachInstances"
          ],
          "Resource" : "*"
        }
      ]
    })
  }

  inline_policy {
    name = "${var.name}-log-policy"
    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
          "Resource" : "*"
        }
      ]
    })
  }
}