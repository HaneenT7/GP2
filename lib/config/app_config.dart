/// App configuration.
/// Use production `/webhook/...` when the n8n workflow is active.
/// Override at build time: `--dart-define=N8N_REVISION_PLAN_WEBHOOK=...`
const String n8nRevisionPlanWebhookUrl = String.fromEnvironment(
  'N8N_REVISION_PLAN_WEBHOOK',
  defaultValue:
      'https://watad-gp.app.n8n.cloud/webhook/a8169d23-0c62-4977-ae5e-8a1d81e353ae',
);
