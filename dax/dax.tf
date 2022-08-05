resource "aws_dax_cluster" "cache" {
  cluster_name          = "ddb-cache"
  iam_role_arn          = aws_iam_role.cache_iam_role.arn
  node_type             = "dax.t3.medium"
  replication_factor    = 3
  description           = "Cache for supplier id query in DynamoDB"
  tags                  = module.tags.tags
  subnet_group_name     = aws_dax_subnet_group.cache_subnet.name
  security_group_ids    = [aws_security_group.cache_sg.id]
  maintenance_window    = "sat:23:00-sun:01:00"
  parameter_group_name  = aws_dax_parameter_group.cache_parameter_group.name
}

data "aws_vpc" "cache_vpc" {
  filter {
    name = "tag:Name"
    values = ["atov-ddb"]
  }
}

data "aws_subnets" "cache_subnet" {
  filter {
    name   = "tag:Name"
    values = ["atov-ddb"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.cache_vpc.id]
  }
}

data "aws_prefix_list" "dynamodb_prefix_list" {
  filter {
    name   = "prefix-list-name"
    values = ["com.amazonaws.${var.region}.dynamodb"]
  }
}

data "aws_security_groups" "lambda_security_group" {
  filter {
    name   = "group-name"
    values = ["atov-lambda-sec-grp"]
  }
}

resource "aws_dax_subnet_group" "cache_subnet" {
  name        = "${var.project}-ddb-cache-${var.environment}-cache"
  subnet_ids  = data.aws_subnets.cache_subnet.ids
  description = "ddb cache subnet"
}

resource "aws_dax_parameter_group" "cache_parameter_group" {
  name        = "${var.project}-ddb-cache-${var.environment}-cache"
  description = "ddb parameter group"

  parameters {
    name  = "query-ttl-millis"
    value = "300000"
  }

  parameters {
    name  = "record-ttl-millis"
    value = "3600000"
  }
}

resource "aws_security_group" "cache_sg" {
  name                   = "atov-cache-sec-grp"
  description            = "Securtiy group to be attached to ${var.project} DAX"
  vpc_id                 = data.aws_vpc.cache_vpc.id
  revoke_rules_on_delete = true
  lifecycle {
    create_before_destroy = true
  }
  tags = module.tags.tags  
}

resource "aws_security_group_rule" "cache_https_ingress_sg_rules" {
  description              = "Ingress to allow connection from lambda to cache"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_groups.lambda_security_group.ids[0]
  security_group_id        = aws_security_group.cache_sg.id
}

resource "aws_security_group_rule" "cache_dax_ingress_sg_rules" {
  description              = "Ingress to allow connection from lambda to cache"
  type                     = "ingress"
  from_port                = 8111
  to_port                  = 8111
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_groups.lambda_security_group.ids[0]
  security_group_id        = aws_security_group.cache_sg.id
}

resource "aws_security_group_rule" "cache_egress_sg_rules" {
  description       = "Egress to reach to to dynamoDB"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_prefix_list.dynamodb_prefix_list.id]
  security_group_id = aws_security_group.cache_sg.id
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    sid     = "DaxTrustedService"
    actions = [
      "sts:AssumeRole"
    ]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = [
        "dax.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "cache_iam_role" {
  name               = "${var.project}-ddb-cache-${var.environment}-cache"
  description        = "IAM role that DAX can assume to get items from DynamoDB"
  tags               = module.tags.tags
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "cache_policy_document" {
  statement {
    sid = "allowDynamoDBAccess"
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:DescribeTable",
      "dax:PutItem",
      "dax:GetItem"
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${local.account_id[var.environment]}:table/*"
    ]
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/Name"

      values = [
        "atov-ddb-cache-${var.environment}"
      ]
    }
  }
}

resource "aws_iam_policy" "cache_policy" {
  name    = "cache-cache-policy"
  policy  = data.aws_iam_policy_document.cache_policy_document.json
  tags    = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "cache_role_policy" {
  role       = aws_iam_role.cache_iam_role.name
  policy_arn = aws_iam_policy.cache_policy.arn
}
