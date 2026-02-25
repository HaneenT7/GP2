/// App configuration.
/// Replace with your n8n webhook URL once the flow is deployed.
const String n8nRevisionPlanWebhookUrl = String.fromEnvironment(
  'N8N_REVISION_PLAN_WEBHOOK',
  defaultValue:
      'https://watad-gp.app.n8n.cloud/webhook-test/deb84f87-d5f1-4549-b83e-f0ee1b66a400',
);
