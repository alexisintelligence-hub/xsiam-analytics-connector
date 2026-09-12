// Name this query Config only in a private local Power BI file. Never commit real values.
[
    BaseUrl = "https://tenant.example.invalid",
    ApiKey = "<API_KEY>",
    ApiKeyId = "<API_KEY_ID>",
    Query = "dataset = Issues | fields xdm.issue.id, xdm.issue.severity, xdm.issue.status.progress, _time, xdm.issue.alert_count, xdm.issue.is_excluded | limit 100",
    LookbackHours = 24,
    MaxAttempts = 12,
    WaitSeconds = 5
]
