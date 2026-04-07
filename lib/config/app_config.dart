/// App configuration.
/// Replace with your n8n webhook URL once the flow is deployed.
const String n8nRevisionPlanWebhookUrl = String.fromEnvironment(
  'N8N_REVISION_PLAN_WEBHOOK',
  defaultValue:
      'https://watad-gp.app.n8n.cloud/webhook/a8169d23-0c62-4977-ae5e-8a1d81e353ae',
);
