// Create a blank query named ContractTests after creating Connector.
// All tests exercise the actual M functions without network access.
let
    C = Connector,
    Row = [#"xdm.issue.id" = "SYNTH-001", #"xdm.issue.severity" = "high", #"_time" = 1767225600000,
        #"xdm.issue.alert_count" = "3", #"xdm.issue.is_excluded" = "false"],
    Good = [reply = [status = "SUCCESS", number_of_results = 1, results = [data = {Row}]]],
    Pending = [reply = [status = "PENDING"]],
    Ndjson = Json.FromValue(Row),
    Stream = [reply = [status = "SUCCESS", number_of_results = 1, results = [stream_id = "SYNTH-STREAM", data = {}]]],
    NoStream = (id as text) as binary => error "UnexpectedStreamCall",
    IsError = (f as function) as logical => (try f())[HasError],
    Check = (name as text, f as function) as record =>
        let Result = try f() in [Test = name, Passed = if Result[HasError] then false else Result[Value] = true],
    Cases = {
        Check("immediate success", () => C[Poll]((n) => Good, 1, 0) = Good),
        Check("pending to success returns terminal response", () => C[Poll]((n) => if n = 1 then Pending else Good, 2, 0) = Good),
        Check("success on final attempt", () => C[Poll]((n) => if n < 3 then Pending else Good, 3, 0) = Good),
        Check("pending times out", () => IsError(() => C[Poll]((n) => Pending, 2, 0))),
        Check("failure is terminal", () => IsError(() => C[Poll]((n) => [reply = [status = "FAIL"]], 2, 0))),
        Check("missing status fails", () => IsError(() => C[Poll]((n) => [reply = []], 2, 0))),
        Check("invalid attempt limit", () => IsError(() => C[Poll]((n) => Good, 0, 0))),
        Check("inline does not call stream", () => List.Count(C[Resolve](Good, NoStream)[Rows]) = 1),
        Check("stream takes precedence over inline preview", () => C[Resolve](Stream, (id) => Ndjson)[Diagnostics][DeliveryMode] = "Stream"),
        Check("gzip stream", () => List.Count(C[ParseNdjson](Binary.Compress(Ndjson, Compression.GZip))[Rows]) = 1),
        Check("blank lines and CRLF", () => C[ParseNdjson](Text.ToBinary("#(cr)#(lf)" & Text.FromBinary(Ndjson) & "#(cr)#(lf)#(cr)#(lf)"))[NonEmptyLines] = 1),
        Check("UTF8 BOM", () => List.Count(C[ParseNdjson](Text.ToBinary(Character.FromNumber(65279) & Text.FromBinary(Ndjson)))[Rows]) = 1),
        Check("malformed NDJSON rejected", () => IsError(() => C[ParseNdjson](Text.ToBinary("{invalid}")))),
        Check("non-record JSON rejected", () => IsError(() => C[ParseNdjson](Text.ToBinary("[]")))),
        Check("count mismatch rejected", () => IsError(() => C[Resolve]([reply = [status = "SUCCESS", number_of_results = 2, results = [data = {Row}]]], NoStream))),
        Check("missing delivery rejected", () => IsError(() => C[Resolve]([reply = [status = "SUCCESS", results = []]], NoStream))),
        Check("empty table keeps six columns", () => Table.ColumnCount(C[Normalize]({})) = 6 and Table.RowCount(C[Normalize]({})) = 0),
        Check("missing field becomes null", () => C[Normalize]({[]}){0}[severity] = null),
        Check("epoch milliseconds are UTC", () => C[Normalize]({Row}){0}[event_time_utc] = #datetimezone(2026, 1, 1, 0, 0, 0, 0, 0)),
        Check("numeric string counter", () => C[Normalize]({Row}){0}[alert_count] = 3),
        Check("logical string", () => C[Normalize]({Row}){0}[is_excluded] = false),
        Check("invalid counter rejected", () => IsError(() => C[Normalize]({[#"xdm.issue.alert_count" = "bad"]}){0}[alert_count])),
        Check("unknown fields are not projected", () => not List.Contains(Table.ColumnNames(C[Normalize]({[unapproved = "synthetic"]})), "unapproved")),
        Check("timeframe uses milliseconds", () => C[Timeframe](24, #datetimezone(2026, 1, 2, 0, 0, 0, 0, 0)) = [from = 1767225600000, to = 1767312000000]),
        Check("execution keeps synthetic query ID", () =>
            let Transport = (endpoint, body, retry) =>
                if endpoint = "start_xql_query" then Json.FromValue([reply = "SYNTH-QUERY"])
                else if endpoint = "get_query_results" and body[request_data][query_id] = "SYNTH-QUERY" and retry then Json.FromValue(Good)
                else error "UnexpectedRequest",
                Result = C[Run](Transport, "synthetic-demo", [from = 0, to = 1], 2, 0)
            in Table.RowCount(Result[Data]) = 1 and not Record.HasFields(Result[Diagnostics], "QueryId"))
    },
    ResultTable = Table.FromRecords(Cases),
    Failed = Table.RowCount(Table.SelectRows(ResultTable, each not [Passed]))
in
    if Failed > 0 then error Error.Record("ContractTestsFailed", "Inspect the Cases step for failing test names.", [FailedCount = Failed]) else ResultTable
