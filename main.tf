###############################################################################
# S3 Buckets
###############################################################################
locals {
  # Resource naming
  source_bucket_name    = "${var.name}-${var.source_bucket_name}"
  processed_bucket_name = "${var.name}-${var.dest_bucket_name}"
  lambda_function_name  = "${var.name}-converter"
  lambda_role_name      = "${var.name}-lambda-role"
  lambda_policy_name    = "${var.name}-lambda-policy"
  lambda_package_path   = "${path.module}/function.zip"

  # Default tags
  default_tags = {
    ManagedBy = "terraform"
    Module    = "s3-heic-converter"
  }

  # Merge default tags with user provided tags
  tags = merge(local.default_tags, var.tags)
}

###############################################################################
# Lambda Package Build
###############################################################################
resource "null_resource" "lambda_package" {
  triggers = {
    source_code = filesha256("${path.module}/lambda/index.mjs")
  }

  provisioner "local-exec" {
    command = <<EOF
      cd ${path.module}/lambda && \
      zip -r ../function.zip .
    EOF
  }
}

data "archive_file" "lambda_package" {
  depends_on  = [null_resource.lambda_package]
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = local.lambda_package_path
}

resource "aws_s3_bucket" "source" {
  bucket = local.source_bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket" "processed" {
  bucket = local.processed_bucket_name
  tags   = local.tags
}

# Enable versioning for both buckets
resource "aws_s3_bucket_versioning" "source" {
  bucket = aws_s3_bucket.source.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id
  versioning_configuration {
    status = "Enabled"
  }
}

###############################################################################
# Lambda Layer
###############################################################################
resource "null_resource" "download_layer" {
  triggers = {
    layer_url = "https://github.com/Dobe-Solutions/sharp-heif-lambda-layer/releases/download/v0.33.5/sharp-heif-lambda-layer-v0.33.5-x64-hevc-av1.zip"
  }

  provisioner "local-exec" {
    command = "curl -L ${self.triggers.layer_url} -o ${path.module}/layer.zip"
  }
}

resource "aws_lambda_layer_version" "sharp_heif" {
  depends_on          = [null_resource.download_layer]
  filename            = "${path.module}/layer.zip"
  layer_name          = "${var.name}-sharp-heif"
  compatible_runtimes = ["nodejs20.x"]
  description         = "Sharp HEIF processing layer v0.33.5"
}

###############################################################################
# Lambda Function
###############################################################################
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = local.lambda_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.tags
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.source.arn,
      "${aws_s3_bucket.source.arn}/*",
      aws_s3_bucket.processed.arn,
      "${aws_s3_bucket.processed.arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = local.lambda_policy_name
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_lambda_function" "heic_converter" {
  filename         = local.lambda_package_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  function_name    = local.lambda_function_name
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 30
  memory_size      = 512
  layers           = [aws_lambda_layer_version.sharp_heif.arn]

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed.id
    }
  }

  tags = local.tags

  depends_on = [null_resource.lambda_package]
}

###############################################################################
# S3 Event Notification
###############################################################################

# Lambda permission to allow S3 to invoke the function
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.heic_converter.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.source.arn
}

# Attach basic Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 bucket notification must be created after the Lambda permission
resource "aws_s3_bucket_notification" "source" {
  depends_on = [aws_lambda_permission.allow_s3]
  bucket     = aws_s3_bucket.source.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.heic_converter.arn
    events              = ["s3:ObjectCreated:*"]
  }
}
