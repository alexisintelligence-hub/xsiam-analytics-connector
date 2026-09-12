# Validation approach and evidence

## Status

- Source review: implementation and architecture references for the same project were cross-checked. Documentation claims about rolling windows, adaptive polling, duplicate prevention and refresh reliability were not treated as proof of shipped behavior. Binary runtime evidence was excluded without reuse.
- Syntax check: all six `.pq` files passed Microsoft's `@microsoft/powerquery-parser` version 2.0.0 on 2026-09-12. This checks grammar, not execution or type correctness. The parser was used locally and is not a runtime dependency.
- Offline artifact checks: run with `node scripts/validate.mjs`; validate synthetic fixture structure, local links and common disclosure patterns. This does not execute M.
- M contract suite: 25 tests supplied in `tests/ContractTests.pq`; execution in Power Query is pending.
- Power BI demo load: pending. Expected two synthetic records and six columns, sorted `SYNTH-002` then `SYNTH-001`.
- Authorized live API and service/gateway refresh: not run. No tenant credentials are included or requested for the portfolio build.

Do not infer runtime correctness from a static check or from the existence of tests. No production performance or business outcomes have been measured for this public edition.

## M contract suite

Create `Connector` and `ContractTests` queries with the exact filenames' contents. Refresh `ContractTests`. Expected: 25 passing rows. A failure raises `ContractTestsFailed`; inspect the `Cases` step for sanitized test names. Tests exercise immediate success, pending-to-success, final-attempt success, timeout, failure/missing status, inline and stream precedence, gzip, CRLF/blank lines, BOM, malformed and non-record JSON, count mismatches, absent delivery, empty schema, missing values, UTC milliseconds, numeric and boolean coercion, projection minimization and execution ID continuity.

The suite uses actual M functions with injected synthetic transports. It does not simulate Power Query's HTTP/authentication engine. Run it in the target Power BI Desktop version and record version, date and pass/fail counts before marking it validated. Do not attach live screenshots or datasets.

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

Publish only reviewed allowlisted source and synthetic fixtures. The PR must contain no source-repository history or evidence assets. Human review is required before merge. Runtime validation remains explicitly pending until performed; this project must not be labelled production-ready based on this checklist alone.
