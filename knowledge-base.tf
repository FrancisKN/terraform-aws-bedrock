# – Existing KBs –

# - Mongo –
resource "awscc_bedrock_knowledge_base" "knowledge_base_mongo" {
  count       = var.create_mongo_config ? 1 : 0
  name        = "${random_string.solution_prefix.result}-${var.kb_name}"
  description = var.kb_description
  role_arn    = var.kb_role_arn != null ? var.kb_role_arn : aws_iam_role.bedrock_knowledge_base_role[0].arn
  tags        = var.kb_tags

  storage_configuration = {
    type = var.kb_storage_type

    mongo_db_atlas_configuration = {
      collection_name        = var.collection_name
      credentials_secret_arn = var.credentials_secret_arn
      database_name          = var.database_name
      endpoint               = var.endpoint
      vector_index_name      = var.vector_index_name
      field_mapping = {
        metadata_field = var.metadata_field
        text_field     = var.text_field
        vector_field   = var.vector_field
      }
      endpoint_service_name = var.endpoint_service_name
    }
  }
  knowledge_base_configuration = {
    type = var.kb_type
    vector_knowledge_base_configuration = {
      embedding_model_arn = var.kb_embedding_model_arn
    }
  }
}

# – Pinecone –
resource "awscc_bedrock_knowledge_base" "knowledge_base_pinecone" {
  count       = var.create_pinecone_config ? 1 : 0
  name        = "${random_string.solution_prefix.result}-${var.kb_name}"
  description = var.kb_description
  role_arn    = var.kb_role_arn != null ? var.kb_role_arn : aws_iam_role.bedrock_knowledge_base_role[0].arn
  tags        = var.kb_tags

  storage_configuration = {
    type = var.kb_storage_type
    pinecone_configuration = {
      connection_string      = var.connection_string
      credentials_secret_arn = var.credentials_secret_arn
      field_mapping = {
        metadata_field = var.metadata_field
        text_field     = var.text_field
      }
      namespace = var.namespace
    }
  }
  knowledge_base_configuration = {
    type = var.kb_type
    vector_knowledge_base_configuration = {
      embedding_model_arn = var.kb_embedding_model_arn
    }
  }
}

# – RDS –
resource "awscc_bedrock_knowledge_base" "knowledge_base_rds" {
  count       = var.create_rds_config ? 1 : 0
  name        = "${random_string.solution_prefix.result}-${var.kb_name}"
  description = var.kb_description
  role_arn    = var.kb_role_arn != null ? var.kb_role_arn : aws_iam_role.bedrock_knowledge_base_role[0].arn
  tags        = var.kb_tags

  storage_configuration = {
    type = var.kb_storage_type
    rds_configuration = {
      credentials_secret_arn = var.credentials_secret_arn
      database_name          = var.database_name
      resource_arn           = var.resource_arn
      table_name             = var.table_name
      field_mapping = {
        metadata_field    = var.metadata_field
        primary_key_field = var.primary_key_field
        text_field        = var.text_field
        vector_field      = var.vector_field
      }
    }
  }
  knowledge_base_configuration = {
    type = var.kb_type
    vector_knowledge_base_configuration = {
      embedding_model_arn = var.kb_embedding_model_arn
    }
  }
}

# - Redshift -
resource "awscc_bedrock_knowledge_base" "knowledge_base_redshift" {
  count       = var.create_redshift_config ? 1 : 0
  name        = "${var.kb_name}-${random_string.solution_prefix.result}"
  description = var.kb_description
  role_arn    = var.kb_role_arn != null ? var.kb_role_arn : aws_iam_role.bedrock_knowledge_base_role[0].arn

  knowledge_base_configuration = {
    type = "SQL"
    sql_knowledge_base_configuration = {
      type = "REDSHIFT"
      redshift_configuration = {
        query_engine_configuration = {
          type = "SERVERLESS"
          serverless_configuration = {
            workgroup_arn = var.kb_redshift_query_engine_configuration_wg
            auth_configuration = {
              type = "IAM"
            }
          }
        }
        query_generation_configuration = {
          execution_timeout_seconds = 200
          generation_context = var.kb_redshift_query_generation_context
        }
        storage_configurations = [{
          type = "AWS_DATA_CATALOG"
          aws_data_catalog_configuration = {
            table_names = var.kb_redshift_query_data_catalog_configuration
          }
        }]
      }
    }
  }

  tags = var.kb_tags
}
