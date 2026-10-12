data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name              = "${var.name_prefix}-${random_id.suffix.hex}"
  api_stage_name    = "image"
  solution_bucket   = "solutions-${var.aws_region}"
  solution_zip_key  = "dynamic-image-transformation-for-amazon-cloudfront/v8.1.1/f218f67363b4ad08032e77561d02aaadd80d93acecf864885640d02815d684ed.zip"
  lambda_log_group  = "/aws/lambda/${local.name}-handler"
  metrics_log_group = "/aws/lambda/${local.name}-metrics"
  metrics_namespace = "DynamicImageTransformation"
  common_tags = {
    ManagedBy = "Terraform"
    Solution  = "dynamic-image-transformation"
    Source    = "AWS-Solutions-SO0023-v8.1.1"
  }
}

data "archive_file" "metrics_wrapper" {
  type        = "zip"
  source_dir  = "${path.module}/metrics-wrapper"
  output_path = "${path.module}/build/metrics-wrapper.zip"
}

resource "aws_iam_role" "image_handler" {
  name = "${local.name}-handler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "image_handler" {
  name = "${local.name}-handler"
  role = aws_iam_role.image_handler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.image_handler.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:${data.aws_partition.current.partition}:s3:::${var.source_bucket}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:${data.aws_partition.current.partition}:s3:::${var.source_bucket}"
      },
      {
        Effect   = "Allow"
        Action   = ["rekognition:DetectFaces", "rekognition:DetectModerationLabels"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "image_handler" {
  name              = local.lambda_log_group
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_lambda_function" "image_handler" {
  function_name = "${local.name}-handler"
  description   = "AWS Solutions SO0023 v8.1.1 image transformation handler"
  role          = aws_iam_role.image_handler.arn
  runtime       = "nodejs22.x"
  handler       = "index.handler"
  memory_size   = 1024
  timeout       = 29

  # This is the immutable AWS Solutions v8.1.1 artifact used by the deleted
  # CloudFormation deployment; Terraform creates and owns the Lambda resource.
  s3_bucket = local.solution_bucket
  s3_key    = local.solution_zip_key

  environment {
    variables = {
      AUTO_WEBP                     = var.enable_auto_webp ? "Yes" : "No"
      CORS_ENABLED                  = var.enable_cors ? "Yes" : "No"
      CORS_ORIGIN                   = var.cors_origin
      SOURCE_BUCKETS                = var.source_bucket
      REWRITE_MATCH_PATTERN         = ""
      REWRITE_SUBSTITUTION          = ""
      ENABLE_SIGNATURE              = "No"
      SECRETS_MANAGER               = ""
      SECRET_KEY                    = ""
      ENABLE_DEFAULT_FALLBACK_IMAGE = "No"
      DEFAULT_FALLBACK_IMAGE_BUCKET = ""
      DEFAULT_FALLBACK_IMAGE_KEY    = ""
      ENABLE_S3_OBJECT_LAMBDA       = "No"
      SOLUTION_VERSION              = "v8.1.1"
      SOLUTION_ID                   = "SO0023"
      SHARP_SIZE_LIMIT              = ""
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.image_handler,
    aws_iam_role_policy.image_handler,
  ]

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "metrics_wrapper" {
  name              = local.metrics_log_group
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_iam_role" "metrics_wrapper" {
  name = "${local.name}-metrics"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "metrics_wrapper" {
  name = "${local.name}-metrics"
  role = aws_iam_role.metrics_wrapper.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.metrics_wrapper.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.image_handler.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:${data.aws_partition.current.partition}:s3:::${var.source_bucket}/*"
      }
    ]
  })
}

resource "aws_lambda_function" "metrics_wrapper" {
  function_name    = "${local.name}-metrics"
  description      = "Measures original and transformed image sizes with CloudWatch EMF"
  role             = aws_iam_role.metrics_wrapper.arn
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  filename         = data.archive_file.metrics_wrapper.output_path
  source_code_hash = data.archive_file.metrics_wrapper.output_base64sha256
  memory_size      = 256
  timeout          = 29

  environment {
    variables = {
      IMAGE_HANDLER_FUNCTION_NAME = aws_lambda_function.image_handler.function_name
      METRICS_NAMESPACE           = local.metrics_namespace
      METRICS_SERVICE             = local.name
      SOURCE_BUCKET               = var.source_bucket
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.metrics_wrapper,
    aws_iam_role_policy.metrics_wrapper,
  ]

  tags = local.common_tags
}

resource "aws_api_gateway_rest_api" "image" {
  name               = "${local.name}-api"
  description        = "Image transformation API"
  binary_media_types = ["*/*"]
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  tags = local.common_tags
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.image.id
  parent_id   = aws_api_gateway_rest_api.image.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.image.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "root" {
  rest_api_id   = aws_api_gateway_rest_api.image.id
  resource_id   = aws_api_gateway_rest_api.image.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id             = aws_api_gateway_rest_api.image.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.metrics_wrapper.invoke_arn
}

resource "aws_api_gateway_integration" "root" {
  rest_api_id             = aws_api_gateway_rest_api.image.id
  resource_id             = aws_api_gateway_rest_api.image.root_resource_id
  http_method             = aws_api_gateway_method.root.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.metrics_wrapper.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.metrics_wrapper.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.image.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "image" {
  rest_api_id = aws_api_gateway_rest_api.image.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.proxy.id,
      aws_api_gateway_integration.proxy.id,
      aws_api_gateway_method.root.id,
      aws_api_gateway_integration.root.id,
      aws_lambda_function.metrics_wrapper.invoke_arn,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.proxy,
    aws_api_gateway_integration.root,
  ]
}

resource "aws_api_gateway_stage" "image" {
  rest_api_id   = aws_api_gateway_rest_api.image.id
  deployment_id = aws_api_gateway_deployment.image.id
  stage_name    = local.api_stage_name
  tags          = local.common_tags
}

resource "aws_s3_bucket" "cloudfront_logs" {
  bucket_prefix = "${var.name_prefix}-logs-"
  force_destroy = true
  tags          = local.common_tags
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]
  bucket     = aws_s3_bucket.cloudfront_logs.id
  acl        = "log-delivery-write"
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  bucket                  = aws_s3_bucket.cloudfront_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = var.log_expiration_days
    }
  }
}

resource "aws_cloudfront_cache_policy" "image" {
  name        = "${local.name}-image-cache"
  comment     = "Cache transformed images by path and all image transformation parameters."
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Accept"]
      }
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

resource "aws_cloudfront_origin_request_policy" "image" {
  name    = "${local.name}-origin-request"
  comment = "Forward CORS origin while query strings are forwarded by the cache policy."

  cookies_config {
    cookie_behavior = "none"
  }
  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["Origin"]
    }
  }
  query_strings_config {
    query_string_behavior = "none"
  }
}

resource "aws_cloudfront_function" "default_transforms" {
  name    = "${local.name}-defaults"
  runtime = "cloudfront-js-2.0"
  comment = "Inject default format and quality without changing image dimensions."
  publish = true
  code = templatefile("${path.module}/edge-defaults.js.tftpl", {
    default_quality = var.default_quality
    default_format  = var.default_format
  })
}

resource "aws_cloudfront_distribution" "image" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.name} image transformation distribution"
  default_root_object = ""
  price_class         = var.cloudfront_price_class
  http_version        = "http2and3"

  origin {
    domain_name = "${aws_api_gateway_rest_api.image.id}.execute-api.${var.aws_region}.amazonaws.com"
    origin_id   = "api-gateway"
    origin_path = "/${aws_api_gateway_stage.image.stage_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = "api-gateway"
    viewer_protocol_policy   = "redirect-to-https"
    compress                 = true
    cache_policy_id          = aws_cloudfront_cache_policy.image.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.image.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.default_transforms.arn
    }
  }

  custom_error_response {
    error_code            = 500
    error_caching_min_ttl = 600
  }
  custom_error_response {
    error_code            = 502
    error_caching_min_ttl = 600
  }
  custom_error_response {
    error_code            = 503
    error_caching_min_ttl = 600
  }
  custom_error_response {
    error_code            = 504
    error_caching_min_ttl = 600
  }

  logging_config {
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    prefix          = "cloudfront/"
    include_cookies = false
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    # CloudFront fixes the minimum at TLSv1 while its default certificate is
    # used. A custom ACM certificate is required to enforce TLSv1.2_2021.
    minimum_protocol_version = "TLSv1"
  }

  tags = local.common_tags

  depends_on = [
    aws_api_gateway_stage.image,
    aws_s3_bucket_acl.cloudfront_logs,
  ]
}
