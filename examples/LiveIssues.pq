// Opt-in: requires Connector, LiveTransport and a private Config query.
let
    Result = Connector[Run](LiveTransport(Config), Config[Query],
        Connector[Timeframe](Config[LookbackHours], DateTimeZone.FixedUtcNow()),
        Config[MaxAttempts], Config[WaitSeconds])
in Result[Data]
