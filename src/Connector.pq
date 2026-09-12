// Create a blank Power Query named Connector and paste this entire expression.
let
    Fail = (code as text) as any => error Error.Record(code, "Connector stopped; inspect only sanitized diagnostics.", null),
    RequiredText = (value as any) as text =>
        if not Value.Is(value, type text) then Fail("InvalidText")
        else if Text.Trim(value) = "" then Fail("EmptyText") else value,
    PositiveInteger = (value as number, maximum as number) as number =>
        if value < 1 or value > maximum or Number.RoundDown(value) <> value then Fail("InvalidLimit") else value,
    Timeframe = (hours as number, now as datetimezone) as record =>
        let
            Checked = PositiveInteger(hours, 8760),
            Epoch = #datetimezone(1970, 1, 1, 0, 0, 0, 0, 0),
            End = Number.RoundDown(Duration.TotalSeconds(now - Epoch) * 1000)
        in [from = End - Checked * 3600000, to = End],
    Poll = (fetch as function, maxAttempts as number, waitSeconds as number) as record =>
        let
            Limit = PositiveInteger(maxAttempts, 120),
            Delay = if waitSeconds >= 0 and waitSeconds <= 60 then waitSeconds else Fail("InvalidDelay"),
            Step = (attempt as number) as record =>
                let
                    Response = fetch(attempt),
                    Reply = try Response[reply] otherwise null,
                    Status = try Reply[status] otherwise null
                in
                    if not Value.Is(Status, type text) then Fail("MissingStatus")
                    else if Status = "SUCCESS" then Response
                    else if Status <> "PENDING" then Fail("QueryFailed")
                    else if attempt >= Limit then Fail("PollingTimeout")
                    else Function.InvokeAfter(() => @Step(attempt + 1), #duration(0, 0, 0, Delay))
        in if Limit >= 1 and Delay >= 0 then Step(1) else Fail("InvalidPollingConfiguration"),
    ParseNdjson = (payload as binary) as record =>
        let
            Bytes = Binary.ToList(Binary.FirstN(payload, 2)),
            IsGzip = Bytes = {31, 139},
            Decoded = if IsGzip then (try Binary.Decompress(payload, Compression.GZip) otherwise Fail("InvalidGzip")) else payload,
            Raw = try Text.FromBinary(Decoded, TextEncoding.Utf8) otherwise Fail("InvalidEncoding"),
            TextValue = if Text.StartsWith(Raw, Character.FromNumber(65279)) then Text.Range(Raw, 1) else Raw,
            Lines = Lines.FromText(TextValue),
            NonEmpty = List.Select(Lines, each Text.Trim(_) <> ""),
            Parsed = List.Transform(NonEmpty, each try Json.Document(_)),
            Valid = List.Select(Parsed, each if [HasError] then false else Value.Is([Value], type record)),
            BadCount = List.Count(NonEmpty) - List.Count(Valid)
        in
            if BadCount > 0 then Fail("InvalidNdjson")
            else [Rows = List.Transform(Valid, each [Value]), NonEmptyLines = List.Count(NonEmpty)],
    Resolve = (response as record, readStream as function) as record =>
        let
            Reply = try response[reply] otherwise null,
            Results = try Reply[results] otherwise null,
            Status = try Reply[status] otherwise null,
            StreamId = try Results[stream_id] otherwise null,
            Data = try Results[data] otherwise null,
            HasStream = if Value.Is(StreamId, type text) then Text.Trim(StreamId) <> "" else false,
            HasInline = Value.Is(Data, type list),
            Count = try Reply[number_of_results] otherwise null,
            CountValid = if Count = null then true else if not Value.Is(Count, type number) then false
                else Count >= 0 and Number.RoundDown(Count) = Count,
            Delivery =
                if Status <> "SUCCESS" then Fail("NotSuccessful")
                else if not Value.Is(Results, type record) then Fail("MissingResults")
                else if HasStream then
                    let Parsed = ParseNdjson(readStream(StreamId))
                    in [Rows = Parsed[Rows], Mode = "Stream", NonEmptyLines = Parsed[NonEmptyLines]]
                else if HasInline then
                    if List.AllTrue(List.Transform(Data, each Value.Is(_, type record))) then
                        [Rows = Data, Mode = "Inline", NonEmptyLines = null]
                    else Fail("InvalidInlineRow")
                else Fail("MissingDelivery"),
            RowCount = List.Count(Delivery[Rows])
        in
            if not CountValid then Fail("InvalidReportedCount")
            else if Count <> null and Count <> RowCount then Fail("RowCountMismatch")
            else [Rows = Delivery[Rows], Diagnostics = [DeliveryMode = Delivery[Mode],
                ApiReportedCount = Count, ParsedRows = RowCount, NonEmptyLines = Delivery[NonEmptyLines]]],
    Normalize = (rows as list) as table =>
        let
            TextOrNull = (x as any) as nullable text => if x = null then null else RequiredText(x),
            CountOrNull = (x as any) as nullable number =>
                if x = null then null else
                let n = if Value.Is(x, type number) then x else if Value.Is(x, type text) then (try Number.FromText(x, "en-US") otherwise Fail("InvalidCounter")) else Fail("InvalidCounter")
                in if n < 0 or Number.RoundDown(n) <> n then Fail("InvalidCounter") else n,
            EpochOrNull = (x as any) as nullable datetimezone =>
                if x = null then null else if not Value.Is(x, type number) then Fail("InvalidEpochMilliseconds")
                else #datetimezone(1970, 1, 1, 0, 0, 0, 0, 0) + #duration(0, 0, 0, x / 1000),
            LogicalOrNull = (x as any) as nullable logical =>
                if x = null then null else if Value.Is(x, type logical) then x
                else if Value.Is(x, type text) then
                    if Text.Lower(x) = "true" then true else if Text.Lower(x) = "false" then false else Fail("InvalidBoolean")
                else Fail("InvalidBoolean"),
            Project = (r as record) as record => [
                issue_id = TextOrNull(Record.FieldOrDefault(r, "xdm.issue.id")),
                severity = TextOrNull(Record.FieldOrDefault(r, "xdm.issue.severity")),
                status = TextOrNull(Record.FieldOrDefault(r, "xdm.issue.status.progress")),
                event_time_utc = EpochOrNull(Record.FieldOrDefault(r, "_time")),
                alert_count = CountOrNull(Record.FieldOrDefault(r, "xdm.issue.alert_count")),
                is_excluded = LogicalOrNull(Record.FieldOrDefault(r, "xdm.issue.is_excluded"))],
            Schema = type table [issue_id = nullable text, severity = nullable text, status = nullable text,
                event_time_utc = nullable datetimezone, alert_count = nullable number, is_excluded = nullable logical],
            TableValue = Table.FromRecords(List.Transform(rows, each Project(_)), Schema, MissingField.UseNull)
        in Table.Sort(TableValue, {{"event_time_utc", Order.Descending}, {"issue_id", Order.Ascending}}),
    Run = (transport as function, query as text, timeframe as record, maxAttempts as number, waitSeconds as number) as record =>
        let
            Body = [request_data = [query = RequiredText(query), timeframe = timeframe]],
            Started = try Json.Document(transport("start_xql_query", Body, false)) otherwise Fail("StartRequestFailed"),
            QueryId = RequiredText(try Started[reply] otherwise null),
            Final = Poll((attempt as number) => (try Json.Document(transport("get_query_results",
                [request_data = [query_id = QueryId, pending_flag = false, format = "json"]], true)) otherwise Fail("ResultsRequestFailed")), maxAttempts, waitSeconds),
            Resolved = Resolve(Final, (streamId as text) => transport("get_query_results_stream",
                [request_data = [stream_id = streamId, is_gzip_compressed = true]], true)),
            Output = Normalize(Resolved[Rows])
        in [Data = Output, Diagnostics = Record.AddField(Resolved[Diagnostics], "NormalizedRows", Table.RowCount(Output))]
in
    [Timeframe = Timeframe, Poll = Poll, ParseNdjson = ParseNdjson, Resolve = Resolve, Normalize = Normalize, Run = Run]
