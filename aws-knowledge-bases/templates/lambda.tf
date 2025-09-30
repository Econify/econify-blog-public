#########################################
# Lambda for Ingestion Jobs
#########################################
resource "aws_lambda_function" "kb_ingestion_lambda" {
  filename         = "lambda.zip"
  function_name    = "kb-ingestion-trigger"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_data_source.kb_s3.id
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "kb-lambda-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_kb_policy" {
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "bedrock:StartIngestionJob"
        ]
        Resource = [
          aws_bedrockagent_knowledge_base.kb.arn
        ]
      }
    ]
  })
}

#########################################
# Lambda Permission for S3
#########################################
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.kb_ingestion_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.kb_bucket.arn
}

#########################################
# Bucket notification trigger
#########################################
resource "aws_s3_bucket_notification" "kb_bucket_notifications" {
  bucket = aws_s3_bucket.kb_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.kb_ingestion_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
}
