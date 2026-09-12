// Optional live adapter; demo and contract tests do not reference this query.
// Standard API key authentication only. Configure credentials outside source control.
(config as record) as function =>
let
    Allowed = {"start_xql_query", "get_query_results", "get_query_results_stream"},
    Parts = try Uri.Parts(config[BaseUrl]) otherwise null,
    ValidOrigin = try Parts[Scheme] = "https" and Parts[Host] <> "tenant.example.invalid"
        and (Parts[Path] = "" or Parts[Path] = "/") and Record.FieldCount(Parts[Query]) = 0
        and (Parts[Fragment] = "" or Parts[Fragment] = null)
        and (Parts[UserName] = "" or Parts[UserName] = null)
        and (Parts[Password] = "" or Parts[Password] = null) otherwise false,
    Send = (endpoint as text, body as record, bypassCache as logical) as binary =>
        if not List.Contains(Allowed, endpoint) then error "UnsupportedEndpoint"
        else if not ValidOrigin then error "InvalidOrigin"
        else if Text.Contains(config[ApiKey], "<") or Text.Contains(config[ApiKeyId], "<")
            or Text.Trim(config[ApiKey]) = "" or Text.Trim(config[ApiKeyId]) = "" then error "PlaceholderCredentials"
        else
            let
                Attempt = try Web.Contents(config[BaseUrl], [
                    RelativePath = "public_api/v1/xql/" & endpoint,
                    Headers = [Authorization = config[ApiKey], #"x-xdr-auth-id" = config[ApiKeyId], #"Content-Type" = "application/json"],
                    Content = Json.FromValue(body), Timeout = #duration(0, 0, 2, 0), IsRetry = bypassCache,
                    ManualStatusHandling = {300, 301, 302, 303, 307, 308, 400, 404, 408, 429, 500, 502, 503, 504}
                ]),
                Payload = if Attempt[HasError] then error "TransportFailed" else Attempt[Value],
                Status = Record.FieldOrDefault(Value.Metadata(Payload), "Response.Status", 200)
            in if Status < 200 or Status >= 300 then error "HttpRequestFailed" else Binary.Buffer(Payload)
in Send
