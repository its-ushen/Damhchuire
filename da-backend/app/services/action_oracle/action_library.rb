module ActionOracle
  class ActionLibrary
    def self.actions
      [
        discord_send_message,
        slack_send_message,
        github_create_issue,
        github_create_commit_status,
        github_trigger_workflow,
        sendgrid_send_email,
        sendgrid_send_template_email,
        pagerduty_create_incident,
        pagerduty_resolve_incident,
        pagerduty_add_note,
        hubspot_create_contact,
        hubspot_create_deal,
        airtable_create_record,
        airtable_update_record,
        airtable_list_records,
        airtable_delete_record,
        notion_create_page,
        notion_update_page,
        notion_append_block,
        notion_query_database,
        datadog_create_event,
        datadog_post_metric,
        opsgenie_create_alert,
        opsgenie_close_alert
      ]
    end

    def self.discord_send_message
      {
        slug: "discord_send_message",
        name: "Discord: Send Message",
        description: "Send a message to a Discord channel using credential 'discord_bot_token'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://discord.com/api/v10/channels/{{channel_id}}/messages",
        headers_template: {
          "Authorization" => "Bot {{credential.discord_bot_token}}",
          "Content-Type" => "application/json"
        },
        body_template: {
          "content" => "{{content}}"
        },
        request_schema: {
          "type" => "object",
          "required" => [ "channel_id", "content" ],
          "properties" => {
            "channel_id" => { "type" => "string" },
            "content" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "id" ],
          "properties" => {
            "id" => { "type" => "string" }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.slack_send_message
      {
        slug: "slack_send_message",
        name: "Slack: Send Incoming Webhook Message",
        description: "Send a simple text message to a Slack incoming webhook URL.",
        enabled: true,
        http_method: "POST",
        url_template: "{{webhook_url}}",
        headers_template: {
          "Content-Type" => "application/json"
        },
        body_template: {
          "text" => "{{text}}"
        },
        request_schema: {
          "type" => "object",
          "required" => [ "webhook_url", "text" ],
          "properties" => {
            "webhook_url" => { "type" => "string" },
            "text" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "string"
        }
      }
    end

    def self.github_create_issue
      {
        slug: "github_create_issue",
        name: "GitHub: Create Issue",
        description: "Create a new issue in a GitHub repository using credential 'github_token'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.github.com/repos/{{owner}}/{{repo}}/issues",
        headers_template: {
          "Authorization" => "Bearer {{credential.github_token}}",
          "Accept" => "application/vnd.github+json",
          "X-GitHub-Api-Version" => "2022-11-28"
        },
        body_template: {
          "title" => "{{title}}",
          "body" => "{{body}}"
        },
        request_schema: {
          "type" => "object",
          "required" => [ "owner", "repo", "title" ],
          "properties" => {
            "owner" => { "type" => "string" },
            "repo" => { "type" => "string" },
            "title" => { "type" => "string" },
            "body" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "number", "html_url" ],
          "properties" => {
            "number" => { "type" => "integer" },
            "html_url" => { "type" => "string" }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.github_create_commit_status
      {
        slug: "github_create_commit_status",
        name: "GitHub: Create Commit Status",
        description: "Set the CI/CD status on a commit using credential 'github_token'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.github.com/repos/{{owner}}/{{repo}}/statuses/{{sha}}",
        headers_template: {
          "Authorization" => "Bearer {{credential.github_token}}",
          "Accept" => "application/vnd.github+json",
          "X-GitHub-Api-Version" => "2022-11-28"
        },
        body_template: {
          "state" => "{{state}}",
          "description" => "{{description}}",
          "context" => "{{context}}"
        },
        request_schema: {
          "type" => "object",
          "required" => [ "owner", "repo", "sha", "state" ],
          "properties" => {
            "owner" => { "type" => "string" },
            "repo" => { "type" => "string" },
            "sha" => { "type" => "string" },
            "state" => { "type" => "string", "enum" => [ "success", "failure", "pending", "error" ] },
            "description" => { "type" => "string" },
            "context" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "id", "state" ],
          "properties" => {
            "id" => { "type" => "integer" },
            "state" => { "type" => "string" }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.github_trigger_workflow
      {
        slug: "github_trigger_workflow",
        name: "GitHub: Trigger Workflow Dispatch",
        description: "Manually trigger a GitHub Actions workflow on a given ref using credential 'github_token'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.github.com/repos/{{owner}}/{{repo}}/actions/workflows/{{workflow_id}}/dispatches",
        headers_template: {
          "Authorization" => "Bearer {{credential.github_token}}",
          "Accept" => "application/vnd.github+json",
          "X-GitHub-Api-Version" => "2022-11-28"
        },
        body_template: {
          "ref" => "{{ref}}"
        },
        request_schema: {
          "type" => "object",
          "required" => [ "owner", "repo", "workflow_id", "ref" ],
          "properties" => {
            "owner" => { "type" => "string" },
            "repo" => { "type" => "string" },
            "workflow_id" => { "type" => "string" },
            "ref" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {}
      }
    end

    def self.sendgrid_send_email
      {
        slug: "sendgrid_send_email",
        name: "SendGrid: Send Email",
        description: "Send a plain-text email via SendGrid using credential 'sendgrid_api_key'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.sendgrid.com/v3/mail/send",
        headers_template: {
          "Authorization" => "Bearer {{credential.sendgrid_api_key}}",
          "Content-Type" => "application/json"
        },
        body_template: {
          "personalizations" => [ { "to" => [ { "email" => "{{to_email}}" } ] } ],
          "from" => { "email" => "{{from_email}}" },
          "subject" => "{{subject}}",
          "content" => [ { "type" => "text/plain", "value" => "{{body}}" } ]
        },
        request_schema: {
          "type" => "object",
          "required" => [ "to_email", "from_email", "subject", "body" ],
          "properties" => {
            "to_email" => { "type" => "string" },
            "from_email" => { "type" => "string" },
            "subject" => { "type" => "string" },
            "body" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {}
      }
    end

    def self.sendgrid_send_template_email
      {
        slug: "sendgrid_send_template_email",
        name: "SendGrid: Send Template Email",
        description: "Send an email using a SendGrid dynamic transactional template using credential 'sendgrid_api_key'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.sendgrid.com/v3/mail/send",
        headers_template: {
          "Authorization" => "Bearer {{credential.sendgrid_api_key}}",
          "Content-Type" => "application/json"
        },
        body_template: {
          "personalizations" => [ { "to" => [ { "email" => "{{to_email}}" } ], "dynamic_template_data" => { "subject" => "{{subject}}", "body" => "{{body}}" } } ],
          "from" => { "email" => "{{from_email}}" },
          "template_id" => "{{template_id}}"
        },
        request_schema: {
          "type" => "object",
          "required" => [ "to_email", "from_email", "template_id" ],
          "properties" => {
            "to_email" => { "type" => "string" },
            "from_email" => { "type" => "string" },
            "template_id" => { "type" => "string" },
            "subject" => { "type" => "string" },
            "body" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {}
      }
    end

    def self.pagerduty_create_incident
      {
        slug: "pagerduty_create_incident",
        name: "PagerDuty: Create Incident",
        description: "Create a new PagerDuty incident using credential 'pagerduty_api_key'. Requires a 'from_email' parameter identifying the requesting user.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.pagerduty.com/incidents",
        headers_template: {
          "Authorization" => "Token token={{credential.pagerduty_api_key}}",
          "Accept" => "application/vnd.pagerduty+json;version=2",
          "Content-Type" => "application/json",
          "From" => "{{from_email}}"
        },
        body_template: {
          "incident" => {
            "type" => "incident",
            "title" => "{{title}}",
            "service" => { "id" => "{{service_id}}", "type" => "service_reference" },
            "urgency" => "{{urgency}}"
          }
        },
        request_schema: {
          "type" => "object",
          "required" => [ "title", "service_id", "from_email" ],
          "properties" => {
            "title" => { "type" => "string" },
            "service_id" => { "type" => "string" },
            "from_email" => { "type" => "string" },
            "urgency" => { "type" => "string", "enum" => [ "high", "low" ] }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "incident" ],
          "properties" => {
            "incident" => {
              "type" => "object",
              "properties" => {
                "id" => { "type" => "string" },
                "incident_number" => { "type" => "integer" },
                "html_url" => { "type" => "string" }
              }
            }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.pagerduty_resolve_incident
      {
        slug: "pagerduty_resolve_incident",
        name: "PagerDuty: Resolve Incident",
        description: "Resolve an open PagerDuty incident using credential 'pagerduty_api_key'.",
        enabled: true,
        http_method: "PUT",
        url_template: "https://api.pagerduty.com/incidents/{{incident_id}}",
        headers_template: {
          "Authorization" => "Token token={{credential.pagerduty_api_key}}",
          "Accept" => "application/vnd.pagerduty+json;version=2",
          "Content-Type" => "application/json",
          "From" => "{{from_email}}"
        },
        body_template: {
          "incident" => { "type" => "incident", "status" => "resolved" }
        },
        request_schema: {
          "type" => "object",
          "required" => [ "incident_id", "from_email" ],
          "properties" => {
            "incident_id" => { "type" => "string" },
            "from_email" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "incident" ],
          "properties" => {
            "incident" => {
              "type" => "object",
              "properties" => {
                "id" => { "type" => "string" },
                "status" => { "type" => "string" }
              }
            }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.pagerduty_add_note
      {
        slug: "pagerduty_add_note",
        name: "PagerDuty: Add Incident Note",
        description: "Add a note to an existing PagerDuty incident using credential 'pagerduty_api_key'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.pagerduty.com/incidents/{{incident_id}}/notes",
        headers_template: {
          "Authorization" => "Token token={{credential.pagerduty_api_key}}",
          "Accept" => "application/vnd.pagerduty+json;version=2",
          "Content-Type" => "application/json",
          "From" => "{{from_email}}"
        },
        body_template: {
          "note" => { "content" => "{{content}}" }
        },
        request_schema: {
          "type" => "object",
          "required" => [ "incident_id", "content", "from_email" ],
          "properties" => {
            "incident_id" => { "type" => "string" },
            "content" => { "type" => "string" },
            "from_email" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "note" ],
          "properties" => {
            "note" => {
              "type" => "object",
              "properties" => {
                "id" => { "type" => "string" },
                "content" => { "type" => "string" }
              }
            }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.hubspot_create_contact
      {
        slug: "hubspot_create_contact",
        name: "HubSpot: Create Contact",
        description: "Create a new contact in HubSpot CRM using credential 'hubspot_access_token'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.hubapi.com/crm/v3/objects/contacts",
        headers_template: {
          "Authorization" => "Bearer {{credential.hubspot_access_token}}",
          "Content-Type" => "application/json"
        },
        body_template: {
          "properties" => {
            "email" => "{{email}}",
            "firstname" => "{{firstname}}",
            "lastname" => "{{lastname}}",
            "phone" => "{{phone}}"
          }
        },
        request_schema: {
          "type" => "object",
          "required" => [ "email" ],
          "properties" => {
            "email" => { "type" => "string" },
            "firstname" => { "type" => "string" },
            "lastname" => { "type" => "string" },
            "phone" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "id" ],
          "properties" => {
            "id" => { "type" => "string" }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.hubspot_create_deal
      {
        slug: "hubspot_create_deal",
        name: "HubSpot: Create Deal",
        description: "Create a new deal in HubSpot CRM using credential 'hubspot_access_token'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.hubapi.com/crm/v3/objects/deals",
        headers_template: {
          "Authorization" => "Bearer {{credential.hubspot_access_token}}",
          "Content-Type" => "application/json"
        },
        body_template: {
          "properties" => {
            "dealname" => "{{dealname}}",
            "amount" => "{{amount}}",
            "dealstage" => "{{dealstage}}",
            "pipeline" => "{{pipeline}}"
          }
        },
        request_schema: {
          "type" => "object",
          "required" => [ "dealname", "dealstage" ],
          "properties" => {
            "dealname" => { "type" => "string" },
            "amount" => { "type" => "string" },
            "dealstage" => { "type" => "string" },
            "pipeline" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "id" ],
          "properties" => {
            "id" => { "type" => "string" }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.airtable_create_record
      {
        slug: "airtable_create_record",
        name: "Airtable: Create Record",
        description: "Create a new record in an Airtable base and table using credential 'airtable_api_key'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.airtable.com/v0/{{base_id}}/{{table_name}}",
        headers_template: {
          "Authorization" => "Bearer {{credential.airtable_api_key}}",
          "Content-Type" => "application/json"
        },
        body_template: {
          "records" => [ { "fields" => { "Name" => "{{name}}", "Notes" => "{{notes}}" } } ]
        },
        request_schema: {
          "type" => "object",
          "required" => [ "base_id", "table_name", "name" ],
          "properties" => {
            "base_id" => { "type" => "string" },
            "table_name" => { "type" => "string" },
            "name" => { "type" => "string" },
            "notes" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "records" ],
          "properties" => {
            "records" => { "type" => "array", "items" => { "type" => "object", "properties" => { "id" => { "type" => "string" } } } }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.airtable_update_record
      {
        slug: "airtable_update_record",
        name: "Airtable: Update Record",
        description: "Update fields on an existing Airtable record using credential 'airtable_api_key'.",
        enabled: true,
        http_method: "PATCH",
        url_template: "https://api.airtable.com/v0/{{base_id}}/{{table_name}}/{{record_id}}",
        headers_template: {
          "Authorization" => "Bearer {{credential.airtable_api_key}}",
          "Content-Type" => "application/json"
        },
        body_template: {
          "fields" => { "Name" => "{{name}}", "Notes" => "{{notes}}", "Status" => "{{status}}" }
        },
        request_schema: {
          "type" => "object",
          "required" => [ "base_id", "table_name", "record_id" ],
          "properties" => {
            "base_id" => { "type" => "string" },
            "table_name" => { "type" => "string" },
            "record_id" => { "type" => "string" },
            "name" => { "type" => "string" },
            "notes" => { "type" => "string" },
            "status" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "id" ],
          "properties" => {
            "id" => { "type" => "string" }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.airtable_list_records
      {
        slug: "airtable_list_records",
        name: "Airtable: List Records",
        description: "Fetch records from an Airtable table using credential 'airtable_api_key'.",
        enabled: true,
        http_method: "GET",
        url_template: "https://api.airtable.com/v0/{{base_id}}/{{table_name}}",
        headers_template: {
          "Authorization" => "Bearer {{credential.airtable_api_key}}"
        },
        body_template: {},
        request_schema: {
          "type" => "object",
          "required" => [ "base_id", "table_name" ],
          "properties" => {
            "base_id" => { "type" => "string" },
            "table_name" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "records" ],
          "properties" => {
            "records" => { "type" => "array", "items" => { "type" => "object", "properties" => { "id" => { "type" => "string" }, "fields" => { "type" => "object" } } } }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.airtable_delete_record
      {
        slug: "airtable_delete_record",
        name: "Airtable: Delete Record",
        description: "Delete a specific record from an Airtable table using credential 'airtable_api_key'.",
        enabled: true,
        http_method: "DELETE",
        url_template: "https://api.airtable.com/v0/{{base_id}}/{{table_name}}/{{record_id}}",
        headers_template: {
          "Authorization" => "Bearer {{credential.airtable_api_key}}"
        },
        body_template: {},
        request_schema: {
          "type" => "object",
          "required" => [ "base_id", "table_name", "record_id" ],
          "properties" => {
            "base_id" => { "type" => "string" },
            "table_name" => { "type" => "string" },
            "record_id" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "deleted", "id" ],
          "properties" => {
            "deleted" => { "type" => "boolean" },
            "id" => { "type" => "string" }
          },
          "additionalProperties" => false
        }
      }
    end

    def self.notion_create_page
      {
        slug: "notion_create_page",
        name: "Notion: Create Database Page",
        description: "Create a new page (row) in a Notion database using credential 'notion_api_key'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.notion.com/v1/pages",
        headers_template: {
          "Authorization" => "Bearer {{credential.notion_api_key}}",
          "Notion-Version" => "2022-06-28",
          "Content-Type" => "application/json"
        },
        body_template: {
          "parent" => { "database_id" => "{{database_id}}" },
          "properties" => {
            "Name" => { "title" => [ { "text" => { "content" => "{{title}}" } } ] },
            "Status" => { "select" => { "name" => "{{status}}" } }
          }
        },
        request_schema: {
          "type" => "object",
          "required" => [ "database_id", "title" ],
          "properties" => {
            "database_id" => { "type" => "string" },
            "title" => { "type" => "string" },
            "status" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "id", "url" ],
          "properties" => {
            "id" => { "type" => "string" },
            "url" => { "type" => "string" }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.notion_update_page
      {
        slug: "notion_update_page",
        name: "Notion: Update Page Properties",
        description: "Update the status property of an existing Notion page using credential 'notion_api_key'.",
        enabled: true,
        http_method: "PATCH",
        url_template: "https://api.notion.com/v1/pages/{{page_id}}",
        headers_template: {
          "Authorization" => "Bearer {{credential.notion_api_key}}",
          "Notion-Version" => "2022-06-28",
          "Content-Type" => "application/json"
        },
        body_template: {
          "properties" => { "Status" => { "select" => { "name" => "{{status}}" } } }
        },
        request_schema: {
          "type" => "object",
          "required" => [ "page_id", "status" ],
          "properties" => {
            "page_id" => { "type" => "string" },
            "status" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "id" ],
          "properties" => {
            "id" => { "type" => "string" }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.notion_append_block
      {
        slug: "notion_append_block",
        name: "Notion: Append Text Block",
        description: "Append a paragraph text block to a Notion page using credential 'notion_api_key'.",
        enabled: true,
        http_method: "PATCH",
        url_template: "https://api.notion.com/v1/blocks/{{block_id}}/children",
        headers_template: {
          "Authorization" => "Bearer {{credential.notion_api_key}}",
          "Notion-Version" => "2022-06-28",
          "Content-Type" => "application/json"
        },
        body_template: {
          "children" => [
            {
              "object" => "block",
              "type" => "paragraph",
              "paragraph" => { "rich_text" => [ { "type" => "text", "text" => { "content" => "{{content}}" } } ] }
            }
          ]
        },
        request_schema: {
          "type" => "object",
          "required" => [ "block_id", "content" ],
          "properties" => {
            "block_id" => { "type" => "string" },
            "content" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "results" ],
          "properties" => {
            "results" => { "type" => "array", "items" => { "type" => "object", "properties" => { "id" => { "type" => "string" } } } }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.notion_query_database
      {
        slug: "notion_query_database",
        name: "Notion: Query Database",
        description: "Query a Notion database filtering by a select property value, using credential 'notion_api_key'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.notion.com/v1/databases/{{database_id}}/query",
        headers_template: {
          "Authorization" => "Bearer {{credential.notion_api_key}}",
          "Notion-Version" => "2022-06-28",
          "Content-Type" => "application/json"
        },
        body_template: {
          "filter" => { "property" => "{{filter_property}}", "select" => { "equals" => "{{filter_value}}" } }
        },
        request_schema: {
          "type" => "object",
          "required" => [ "database_id", "filter_property", "filter_value" ],
          "properties" => {
            "database_id" => { "type" => "string" },
            "filter_property" => { "type" => "string" },
            "filter_value" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "results" ],
          "properties" => {
            "results" => { "type" => "array", "items" => { "type" => "object", "properties" => { "id" => { "type" => "string" } } } }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.datadog_create_event
      {
        slug: "datadog_create_event",
        name: "Datadog: Create Event",
        description: "Post a custom event to the Datadog event stream using credential 'datadog_api_key'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.datadoghq.com/api/v1/events",
        headers_template: {
          "DD-API-KEY" => "{{credential.datadog_api_key}}",
          "Content-Type" => "application/json"
        },
        body_template: {
          "title" => "{{title}}",
          "text" => "{{text}}",
          "alert_type" => "{{alert_type}}"
        },
        request_schema: {
          "type" => "object",
          "required" => [ "title", "text" ],
          "properties" => {
            "title" => { "type" => "string" },
            "text" => { "type" => "string" },
            "alert_type" => { "type" => "string", "enum" => [ "info", "warning", "error", "success" ] }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "event" ],
          "properties" => {
            "event" => { "type" => "object", "properties" => { "id" => { "type" => "integer" } } }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.datadog_post_metric
      {
        slug: "datadog_post_metric",
        name: "Datadog: Post Custom Metric",
        description: "Submit a custom gauge metric point to Datadog using credential 'datadog_api_key'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.datadoghq.com/api/v2/series",
        headers_template: {
          "DD-API-KEY" => "{{credential.datadog_api_key}}",
          "Content-Type" => "application/json"
        },
        body_template: {
          "series" => [
            {
              "metric" => "{{metric_name}}",
              "type" => 3,
              "points" => [ { "timestamp" => "{{timestamp}}", "value" => "{{value}}" } ],
              "resources" => [ { "name" => "{{host}}", "type" => "host" } ]
            }
          ]
        },
        request_schema: {
          "type" => "object",
          "required" => [ "metric_name", "value", "timestamp" ],
          "properties" => {
            "metric_name" => { "type" => "string" },
            "value" => { "type" => "number" },
            "timestamp" => { "type" => "integer" },
            "host" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "properties" => {
            "errors" => { "type" => "array", "items" => { "type" => "string" } }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.opsgenie_create_alert
      {
        slug: "opsgenie_create_alert",
        name: "Opsgenie: Create Alert",
        description: "Create a new on-call alert in Opsgenie using credential 'opsgenie_api_key'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.opsgenie.com/v2/alerts",
        headers_template: {
          "Authorization" => "GenieKey {{credential.opsgenie_api_key}}",
          "Content-Type" => "application/json"
        },
        body_template: {
          "message" => "{{message}}",
          "description" => "{{description}}",
          "priority" => "{{priority}}",
          "alias" => "{{alias}}"
        },
        request_schema: {
          "type" => "object",
          "required" => [ "message" ],
          "properties" => {
            "message" => { "type" => "string" },
            "description" => { "type" => "string" },
            "priority" => { "type" => "string", "enum" => [ "P1", "P2", "P3", "P4", "P5" ] },
            "alias" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "requestId", "result" ],
          "properties" => {
            "requestId" => { "type" => "string" },
            "result" => { "type" => "string" }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.opsgenie_close_alert
      {
        slug: "opsgenie_close_alert",
        name: "Opsgenie: Close Alert",
        description: "Close an existing Opsgenie alert by its identifier using credential 'opsgenie_api_key'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://api.opsgenie.com/v2/alerts/{{alert_identifier}}/close",
        headers_template: {
          "Authorization" => "GenieKey {{credential.opsgenie_api_key}}",
          "Content-Type" => "application/json"
        },
        body_template: {
          "note" => "{{note}}",
          "source" => "{{source}}"
        },
        request_schema: {
          "type" => "object",
          "required" => [ "alert_identifier" ],
          "properties" => {
            "alert_identifier" => { "type" => "string" },
            "note" => { "type" => "string" },
            "source" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "requestId", "result" ],
          "properties" => {
            "requestId" => { "type" => "string" },
            "result" => { "type" => "string" }
          },
          "additionalProperties" => true
        }
      }
    end
  end
end
