# Architecture and technical decisions

## API contract

The adapter uses POST requests with a JSON `request_data` envelope. `start_xql_query` receives XQL and epoch-millisecond `timeframe.from/to`; the implementation expects a nonempty string in `reply`. `get_query_results` receives that same query ID, `pending_flag=false` and `format=json`. Polling accepts `PENDING` and `SUCCESS`; other statuses fail explicitly.

On success, the resolver expects `reply.results.data` as a list or `reply.results.stream_id` as a nonempty string. A stream ID takes precedence over an inline preview. The stream request sends `stream_id` and `is_gzip_compressed=true`. Its response is interpreted as gzip bytes or already decoded UTF-8 NDJSON based on the gzip magic bytes.

These are deliberately narrow adapter assumptions, not a claim of universal API compatibility. Compare them with current tenant documentation and authorized runtime responses before deployment. Official references: [start query](https://docs-cortex.paloaltonetworks.com/r/Cortex-XSIAM-REST-API/Start-an-XQL-query), [query results](https://docs-cortex.paloaltonetworks.com/r/Cortex-XSIAM-REST-API/Get-XQL-query-results), [stream results](https://docs-cortex.paloaltonetworks.com/r/Cortex-XSIAM-Platform-APIs/Get-XQL-query-results-Stream?contentId=Dm0qyhaD6O29P1io3960~g). Reference discovery was checked on 2026-09-12; some documentation URLs redirect, so a complete current contract verification remains pending.

## Public output contract

One row per returned issue record; the code does not deduplicate records or enforce unique issue IDs. Counts describe returned records, not necessarily distinct issues. Before building a distinct-issue measure, validate the dataset grain.

| Column | Type | Source key |
| --- | --- | --- |
| issue_id | nullable text | xdm.issue.id |
| severity | nullable text | xdm.issue.severity |
| status | nullable text | xdm.issue.status.progress |
| event_time_utc | nullable datetimezone | _time, numeric epoch milliseconds |
| alert_count | nullable number, nonnegative integer | xdm.issue.alert_count |
| is_excluded | nullable logical | xdm.issue.is_excluded |

Missing fields become null. Invalid present values raise errors; they are not silently replaced with null. Counter strings use an explicit `en-US` culture. Timestamps accept numeric epoch milliseconds only. Severity/status retain source text; no assumed enumeration or inferred business meaning is introduced. Unknown fields are discarded. Empty input preserves the same six columns.

## Decisions and trade-offs

| Decision | Benefit | Cost / limitation |
| --- | --- | --- |
| Inject binary transport into M core | Actual orchestration can be tested offline | Not a packaged custom connector |
| Recursive bounded polling | Returns terminal response, including success on last attempt | No persisted job state or cancellation endpoint |
| IsRetry on result retrieval | Avoids serving cached pending results | More network calls; service behavior still requires testing |
| One normalizer for inline and stream | Consistent output and empty schema | Explicit adapter needed for other datasets |
| Fail on malformed nonempty NDJSON | No silently dropped records | One bad row stops the refresh |
| Compare reported count with parsed count | Detects incomplete retrieval | Count semantics must match the provider; partitioned delivery is unsupported |
| Gzip signature detection | Handles compressed or already decompressed bytes | Entire payload and parsed records reside in memory |
| Counts-only diagnostics | Reduces accidental disclosure | Less detailed debugging; local diagnostics still need access control |
| No automatic retry of query start | Avoids accidental duplicate query execution | Transient failures require deliberate rerun |
| Reject redirects in live adapter | Reduces credential forwarding risk | Tenant must provide a direct API origin |

The attempt bound includes the first poll. With 12 attempts and a five-second delay there are at most 11 deliberate waits, plus network execution time. This is not a wall-clock deadline. Each HTTP request has a two-minute timeout; Power Query can apply its own engine-level behavior. Standard-key authentication only is supported. Generic M queries cannot fully control every host-level authentication or tracing behavior.

## Power BI implications

Only enable loading for the final data query. Editor previews and independent query evaluations may trigger additional live executions; the single-invocation execution scope is not an exactly-once guarantee across refreshes. Begin with bounded queries and reconcile source, parsed and loaded counts. Scheduled refresh, gateway credentials, privacy levels and query folding are not validated. No PBIX, model, measures or dashboard are shipped.
