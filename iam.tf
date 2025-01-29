# – IAM –
locals {
  create_kb_role = var.kb_role_arn == null && var.create_default_kb
}


resource "aws_iam_role" "agent_role" {
  count              = var.create_agent ? 1 : 0
  assume_role_policy = data.aws_iam_policy_document.agent_trust[0].json
  name_prefix        = var.name_prefix
}

resource "aws_iam_role_policy" "agent_policy" {
  count  = var.create_agent ? 1 : 0
  policy = data.aws_iam_policy_document.agent_permissions[0].json
  role   = aws_iam_role.agent_role[0].id
}

resource "aws_iam_role_policy" "kb_policy" {
  count  = var.create_kb && var.create_agent ? 1 : 0
  policy = data.aws_iam_policy_document.knowledge_base_permissions[0].json
  role   = aws_iam_role.agent_role[0].id
}

# Define the IAM role for Amazon Bedrock Knowledge Base
resource "aws_iam_role" "bedrock_knowledge_base_role" {
  count = var.kb_role_arn != null ? 0 : 1
  name  = "AmazonBedrockExecutionRoleForKnowledgeBase-${var.name_prefix}"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "bedrock.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# Attach a policy to allow necessary permissions for the Bedrock Knowledge Base
resource "aws_iam_policy" "bedrock_knowledge_base_policy" {
  count = var.kb_role_arn != null ? 0 : 1
  name  = "AmazonBedrockKnowledgeBasePolicy-${var.name_prefix}"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "bedrock:*",
          "redshift-serverless:*",
          "redshift:*",
          "glue:*",
          "sqlworkbench:DeleteSqlGenerationContext"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "BaseS3BucketPermissions",
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListAllMyBuckets"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "bedrock_knowledge_base_policy_s3" {
  count = var.kb_role_arn != null || var.create_s3_data_source == false ? 0 : 1
  name  = "AmazonBedrockKnowledgeBasePolicyS3DataSource-${random_string.solution_prefix.result}"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket",
        ],
        "Resource" : var.kb_s3_data_source == null ? awscc_s3_bucket.s3_data_source[0].arn : var.kb_s3_data_source
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
        ],
        "Resource" : var.kb_s3_data_source == null ? "${awscc_s3_bucket.s3_data_source[0].arn}/*" : "${var.kb_s3_data_source}/*"
      }
    ]
  })
}

resource "aws_iam_policy" "bedrock_kb_s3_decryption_policy" {
  count = local.create_kb_role && var.kb_s3_data_source_kms_arn != null && var.create_s3_data_source ? 1 : 0
  name  = "AmazonBedrockS3KMSPolicyForKnowledgeBase_${random_string.solution_prefix.result}"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "kms:Decrypt",
        "Resource" : var.kb_s3_data_source_kms_arn
        "Condition" : {
          "StringEquals" : {
            "kms:ViaService" : ["s3.${data.aws_region.current.name}.amazonaws.com"]
          }
        }
      }
    ]
  })
}

# Attach the policies to the role
resource "aws_iam_role_policy_attachment" "bedrock_knowledge_base_policy_attachment" {
  count      = var.kb_role_arn != null || var.create_kb == false ? 0 : 1
  role       = aws_iam_role.bedrock_knowledge_base_role[0].name
  policy_arn = aws_iam_policy.bedrock_knowledge_base_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "bedrock_kb_s3_decryption_policy_attachment" {
  count      = local.create_kb_role && var.kb_s3_data_source_kms_arn != null && var.create_s3_data_source ? 1 : 0
  role       = aws_iam_role.bedrock_knowledge_base_role[0].name
  policy_arn = aws_iam_policy.bedrock_kb_s3_decryption_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "bedrock_knowledge_base_policy_s3_attachment" {
  count      = var.kb_role_arn != null || var.create_kb == false || var.create_s3_data_source == false ? 0 : 1
  role       = aws_iam_role.bedrock_knowledge_base_role[0].name
  policy_arn = aws_iam_policy.bedrock_knowledge_base_policy_s3[0].arn
}

resource "aws_iam_role_policy" "bedrock_kb_oss" {
  count = var.kb_role_arn != null ? 0 : 1
  name  = "AmazonBedrockOSSPolicyForKnowledgeBase_${var.kb_name}"
  role  = aws_iam_role.bedrock_knowledge_base_role[count.index].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["aoss:*"]
        Effect   = "Allow"
        Resource = ["arn:aws:aoss:${local.region}:${local.account_id}:*/*"]
      }
    ]
  })
}

# Guardrails Policies

resource "aws_iam_role_policy" "guardrail_policy" {
  count = var.create_guardrail ? 1 : 0
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:ApplyGuardrail",
        ]
        Resource = awscc_bedrock_agent.bedrock_agent[0].guardrail_configuration.guardrail_identifier
      }
    ]
  })
  role = aws_iam_role.agent_role[0].id
}

# Action Group Policies

resource "aws_lambda_permission" "allow_bedrock_agent" {
  count         = var.create_ag ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_action_group_executor
  principal     = "bedrock.amazonaws.com"
  source_arn    = awscc_bedrock_agent.bedrock_agent[0].agent_arn
}

resource "aws_iam_role_policy" "action_group_policy" {
  count = var.create_ag ? 1 : 0
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeModel"
        Resource = var.lambda_action_group_executor
      }
    ]
  })
  role = aws_iam_role.agent_role[0].id
}

# Application Inference Profile Policies

# Define the IAM role for Application Inference Profile
resource "aws_iam_role" "application_inference_profile_role" {
  count = var.create_app_inference_profile ? 1 : 0
  name  = "ApplicationInferenceProfile-${random_string.solution_prefix.result}"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "bedrock.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "app_inference_profile_policy" {
  count = var.create_app_inference_profile ? 1 : 0
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "bedrock:InvokeModel*",
          "bedrock:CreateInferenceProfile"
        ],
        "Resource" : [
          "arn:aws:bedrock:*::foundation-model/*",
          "arn:aws:bedrock:*:*:inference-profile/*",
          "arn:aws:bedrock:*:*:application-inference-profile/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "bedrock:GetInferenceProfile",
          "bedrock:ListInferenceProfiles",
          "bedrock:DeleteInferenceProfile",
          "bedrock:TagResource",
          "bedrock:UntagResource",
          "bedrock:ListTagsForResource"
        ],
        "Resource" : [
          "arn:aws:bedrock:*:*:inference-profile/*",
          "arn:aws:bedrock:*:*:application-inference-profile/*"
        ]
      }
    ]
  })
  role = aws_iam_role.application_inference_profile_role[0].id
}

# Custom model 

resource "aws_iam_role" "custom_model_role" {
  count              = var.create_custom_model ? 1 : 0
  assume_role_policy = data.aws_iam_policy_document.custom_model_trust[0].json
  name_prefix        = "CustomModelRole"
}

resource "aws_iam_role_policy" "custom_model_policy" {
  count = var.create_custom_model ? 1 : 0
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "kms:Decrypt"
        ],
        "Resource" : [
          "arn:aws:s3:::${var.custom_model_training_uri}",
          "arn:aws:s3:::${var.custom_model_training_uri}/*",
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:PrincipalAccount" : local.account_id
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "kms:Decrypt"
        ],
        "Resource" : var.custom_model_output_uri == null ? "arn:aws:s3:::${awscc_s3_bucket.custom_model_output[0].id}/" : "arn:aws:s3:::${var.custom_model_output_uri}",

        "Condition" : {
          "StringEquals" : {
            "aws:PrincipalAccount" : local.account_id
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "kms:Decrypt"
        ],
        "Resource" : var.custom_model_output_uri == null ? "arn:aws:s3:::${awscc_s3_bucket.custom_model_output[0].id}/*" : "arn:aws:s3:::${var.custom_model_output_uri}/*",
        "Condition" : {
          "StringEquals" : {
            "aws:PrincipalAccount" : local.account_id
          }
        }
      },
    ]
  })
  role = aws_iam_role.custom_model_role[0].id
}
