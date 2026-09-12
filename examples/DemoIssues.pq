// Offline synthetic demonstration; create Connector first, then DemoIssues.
let
    Rows = {
        [#"xdm.issue.id" = "SYNTH-001", #"xdm.issue.severity" = "high", #"xdm.issue.status.progress" = "new",
            #"_time" = 1767225600000, #"xdm.issue.alert_count" = 3, #"xdm.issue.is_excluded" = false],
        [#"xdm.issue.id" = "SYNTH-002", #"xdm.issue.severity" = "low", #"xdm.issue.status.progress" = "resolved",
            #"_time" = 1767312000000, #"xdm.issue.alert_count" = "1", #"xdm.issue.is_excluded" = "false"]
    },
    Inline = [reply = [status = "SUCCESS", number_of_results = 2, results = [data = Rows]]],
    Transport = (endpoint as text, body as record, bypassCache as logical) as binary =>
        if endpoint = "start_xql_query" then Json.FromValue([reply = "SYNTH-QUERY"])
        else if endpoint = "get_query_results" then Json.FromValue(Inline)
        else error "UnexpectedDemoEndpoint",
    Result = Connector[Run](Transport, "synthetic-demo", [from = 1767225600000, to = 1767398400000], 2, 0)
in Result[Data]
