/// App configuration.
/// Use production `/webhook/...` when the n8n workflow is active.
/// Override at build time: `--dart-define=N8N_REVISION_PLAN_WEBHOOK=...`
const String n8nRevisionPlanWebhookUrl = String.fromEnvironment(
  'N8N_REVISION_PLAN_WEBHOOK',
  defaultValue:
      'https://watad-gp.app.n8n.cloud/webhook-test/a8169d23-0c62-4977-ae5e-8a1d81e353ae',
);


/// Optional separate n8n URL for regenerate / reschedule-overdue.
/// Override at build time: `--dart-define=N8N_REGENERATE_REVISION_PLAN_WEBHOOK=...`
/// If empty, [RevisionPlanRegenerateClient] falls back to [n8nRevisionPlanWebhookUrl].
const String n8nRegenerateRevisionPlanWebhookUrl = String.fromEnvironment(
  'N8N_REGENERATE_REVISION_PLAN_WEBHOOK',
  defaultValue:
      'https://watad-gp.app.n8n.cloud/webhook/c6311cde-2480-41cf-9168-c7fdd1e9e18a',
);
