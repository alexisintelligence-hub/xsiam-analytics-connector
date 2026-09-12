# Validation approach and evidence

## Status

- Source review: implementation and architecture references for the same project were cross-checked. Documentation claims about rolling windows, adaptive polling, duplicate prevention and refresh reliability were not treated as proof of shipped behavior. Binary runtime evidence was excluded without reuse.
- Syntax check: all six `.pq` files passed Microsoft's `@microsoft/powerquery-parser` version 2.0.0 on 2026-09-12. This checks grammar, not execution or type correctness. The parser was used locally and is not a runtime dependency.
- Offline artifact checks: run with `node scripts/validate.mjs`; validate synthetic fixture structure, local links and common disclosure patterns. This does not execute M.
- M contract suite: **PASS, 25/25 with `Passed = true`**, executed on 2026-09-12 using Microsoft Power Query SDK Tools 2.152.3 (build 0) / Mashup Engine 2.152.856 (build 0).
- Offline demo M execution: **PASS**, executed after the contract suite in the same engine: two synthetic records, six columns, sorted `SYNTH-002` then `SYNTH-001`.
- Power BI Desktop UI/model load: pending. SDK execution is not evidence of successful Desktop loading or service refresh.
- Authorized live API and service/gateway refresh: not run. No tenant credentials are included or requested for the portfolio build.

Do not infer runtime correctness from a static check or from the existence of tests. No production performance or business outcomes have been measured for this public edition.

## Runtime findings and corrections

The initial real-engine run failed five tests despite passing the syntax parser. `Binary.FirstN` is not a recognized M function. Gzip signature inspection now uses `Binary.Range` with a length capped at the available bytes, including empty/short payloads.

After that correction, the suite exposed one remaining failure: when `number_of_results` was absent, lazy record evaluation could defer delivery validation. The resolver now evaluates the row count before returning its result, so missing delivery raises an error even without a reported count. No test was removed or weakened. The unchanged 25-test suite then passed, followed by the demo.

The runner bound the exact `src/Connector.pq` expression to a local `Connector` variable and evaluated the exact test/demo expression in that scope. It did not translate M to another language. `LiveTransport`, `LiveIssues` and real configuration were not loaded. Both final results had `Status = Passed` and empty `DataSourceAnalysis`; no tenant connection or real credentials were used. PQTest can exit with code zero for a failed query, so validation checked the JSON status and every test row, not just the process exit code.

Observed demo columns: `issue_id`, `severity`, `status`, `event_time_utc`, `alert_count`, `is_excluded`. Record order: `SYNTH-002`, then `SYNTH-001`. The contract suite independently passed the UTC epoch conversion assertion. SDK results do not certify Power BI timezone display or model conversion.

## M contract suite

Create `Connector` and `ContractTests` queries with the exact filenames' contents. Refresh `ContractTests`. Expected: 25 passing rows. A failure raises `ContractTestsFailed`; inspect the `Cases` step for sanitized test names. Tests exercise immediate success, pending-to-success, final-attempt success, timeout, failure/missing status, inline and stream precedence, gzip, CRLF/blank lines, BOM, malformed and non-record JSON, count mismatches, absent delivery, empty schema, missing values, UTC milliseconds, numeric and boolean coercion, projection minimization and execution ID continuity.

The suite uses actual M functions with injected synthetic transports. It does not simulate Power Query's HTTP/authentication engine. Repeat it in the target Power BI Desktop version and record version, date and pass/fail counts before claiming Desktop compatibility. Do not attach live screenshots or datasets.

### Reproduce the SDK run

From the repository root in PowerShell, set `$pqTest` to your installed SDK's `PQTest.exe` path and run the following. The wrapper uses only the exact core and synthetic expressions. Results and the unused isolated credential-cache path are outside the repository.

```powershell
$pqTest = '<PATH_TO_PQTEST_EXE>'
$runDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('xql-synthetic-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $runDirectory | Out-Null
$core = Get-Content src/Connector.pq -Raw
foreach ($query in @('tests/ContractTests.pq', 'examples/DemoIssues.pq')) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($query)
    $file = Join-Path $runDirectory ($name + '.pq')
    $expression = Get-Content $query -Raw
    [System.IO.File]::WriteAllText($file, "let Connector = (`n$core`n), Result = (`n$expression`n) in Result")
    $json = & $pqTest run-test -q $file -cfp (Join-Path $runDirectory 'unused-credentials.json') -p
    $result = @($json | ConvertFrom-Json)[0]
    if ($result.Status -ne 'Passed') { throw "$name failed" }
    if ($name -eq 'ContractTests') {
        if ($result.RowCount -ne 25 -or @($result.Output | Where-Object Passed -ne $true).Count -ne 0) { throw 'Contract mismatch' }
    } else {
        $columns = @($result.Output[0].PSObject.Properties.Name)
        if ($result.RowCount -ne 2 -or $columns.Count -ne 6 -or $result.Output[0].issue_id -ne 'SYNTH-002' -or $result.Output[1].issue_id -ne 'SYNTH-001') { throw 'Demo mismatch' }
    }
    $result.Output
}
```

## Authorized live acceptance checklist

### Investigation method

Use a short cycle: hypothesis → controlled case → observation → decision. Keep documented provider behavior, a locally observed response and an untested explanation separate. AI can help propose hypotheses and organize the investigation; it cannot establish API behavior without evidence.

For a UI/API count discrepancy, fix the same absolute UTC interval, dataset, filters, explicit result limits and permissions before comparing counts. Check the UI's effective time selection as well as query text; do not automatically attribute a discrepancy to timeframe handling. Confirm source freshness and record grain, then reconcile delivery, parsed, normalized and loaded counts. Keep real execution identifiers and payloads private.

For schema variation, distinguish missing optional fields from invalid values in projected fields and unexpected nested structures. The current contract permits the first, rejects invalid projected values and discards unapproved fields. It does not flatten arbitrary nested records. For changing delivery modes, record sanitized status sequences and whether an inline or stream path was selected; investigate unexplained transitions before broadening the accepted API contract.

### Live checks

1. Confirm standard API-key authentication, exact API origin, least privilege and current provider contract.
2. Start a bounded query; confirm the start response shape and same execution ID across polling and stream retrieval without publishing identifiers.
3. Validate pending-to-success, terminal error, timeout and 429 behavior. Confirm HTTP metadata is retained and status failures are rejected before parsing.
4. Exercise inline, empty and stream results, including actual compression behavior. Confirm stream is complete and reported counts represent the same scope.
5. Reconcile reported records, parsed records, normalized records and loaded Power BI records. Confirm duplicate/unique-key behavior before defining measures.
6. Validate source field names, types, UTC conversion and missing-value handling. Confirm malformed values remain visible as failures.
7. Confirm preview/evaluation does not create unexpected cost. Test privacy levels, local credential handling, refresh and gateway behavior separately.
8. Inspect logs and errors for data disclosure. Record only sanitized status and counts. Measure memory/runtime on an approved bounded dataset before increasing query size.

## Release criteria

Publish only reviewed allowlisted source and synthetic fixtures. The PR must contain no source-repository history or evidence assets. Human review is required before merge. Synthetic M execution has passed in the SDK; Desktop load, live API, service/gateway refresh and production validation remain pending. This project must not be labelled production-ready based on these checks alone.
