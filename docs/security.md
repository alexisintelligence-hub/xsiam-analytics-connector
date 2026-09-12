# Security considerations and publication audit

## Publication scope

This public edition is reconstructed as a new set of files. No private Git objects, branches, tags, commit messages, release assets or operational screenshots belong in this repository. Only generalized orchestration, parsing and schema-projection patterns are retained.

The source review found placeholder credentials in tracked parameter files. It also identified runtime return structures capable of carrying authentication headers, credential context and raw failed-row samples. The public implementation does not return those structures. This is a current-tree review, not a forensic certification of private history or untracked local files.

A second architecture reference for the same project was also reviewed. Its sanitized M source still exposes request/context and failed-row diagnostic surfaces, so those structures were not imported. Only rewritten, generalizable design rationale and investigation methods were retained. Narrative claims about completed windowing, adaptive polling, duplicate prevention, memory safety and stable refresh were excluded as implementation evidence; proposed work is labelled explicitly. Source repository addresses, historical identifiers and original documentation files are not published here.

Excluded entirely: runtime screenshots, operational notes and test-run evidence, original changelog/status narrative, real query/stream/tenant identifiers, internal names, assignments, free-text incident descriptions, raw errors, request headers and bodies in diagnostics. The runtime screenshot is excluded by category and was not visually inspected; no claim is made about its contents. Fixture identifiers use `SYNTH-` and all records were authored for this demo. No private deployment or result is claimed as public validation evidence.

## Live execution boundary

Published examples are synthetic; a configured live connector retrieves real data. Normalization does not anonymize real issue IDs or categorical values. Keep all live output private, apply organizational access and retention controls, and never publish it as portfolio evidence. Minimize selected fields at the query source. The field allowlist is a schema contract, not a data-loss-prevention system.

Store real credentials outside Git, use the least privilege sufficient for the selected dataset, verify the HTTPS API origin independently and rotate credentials according to organizational policy. A Power Query parameter and a local PBIX are not a vault. Local previews, host errors, tracing and gateway logs can still contain sensitive information even when connector diagnostics are sanitized.

The live adapter blocks unknown paths and redirects and checks a basic HTTPS origin shape. It cannot decide whether a user-entered origin is trustworthy. No credentials are used by the offline demo or tests. No live request was made during preparation of this edition.

`.gitignore` reduces accidental additions of local configuration, Power BI containers, secrets, logs and runtime evidence. It does not protect files already tracked, arbitrary renamed files or screenshots placed elsewhere. Inspect every staged file and run an approved secret scanner before publication. The included artifact checker is a limited pattern-based guardrail, not a comprehensive secret scanner.

## Safe troubleshooting

Inspect error codes, delivery mode and row counts. Do not add tokens, tenant addresses, raw rows, signed URLs or provider error bodies to public issues. Reproduce with synthetic fixtures. If a real secret is disclosed, revoke it and follow the provider's removal procedure; deleting a file in a later commit is insufficient.
