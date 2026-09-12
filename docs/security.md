# Security considerations and publication audit

## Publication scope

This public edition is reconstructed as a new set of files. No private Git history, branches, tags, commit messages, release assets or unredacted operational screenshots are imported. Generalized orchestration, parsing and schema-projection patterns are retained. One explicitly authorized edited visual reference is described below.

The source review found placeholder credentials in tracked parameter files. It also identified runtime return structures capable of carrying authentication headers, credential context and raw failed-row samples. The public implementation does not return those structures. This is a current-tree review, not a forensic certification of private history or untracked local files.

A second architecture reference for the same project was also reviewed. Its sanitized M source still exposes request/context and failed-row diagnostic surfaces, so those structures were not imported. Only rewritten, generalizable design rationale and investigation methods were retained. Narrative claims about completed windowing, adaptive polling, duplicate prevention, memory safety and stable refresh were excluded as implementation evidence; proposed work is labelled explicitly. Source repository addresses, historical identifiers and original documentation files are not published here.

Excluded: unredacted runtime screenshots, operational notes and test-run evidence, original changelog/status narrative, real query/stream/tenant identifiers, internal names, assignments, free-text incident descriptions, raw errors, request headers and bodies in diagnostics. Fixture identifiers use `SYNTH-` and all fixture records were authored for this demo. No private deployment or result is claimed as validation evidence for the public implementation.

### Authorized visual reference

`assets/xsiam-powerbi-redacted.png` is an AI-edited derivative of a historical screenshot, requested by the author. The identifying document/account text, query identifier, category labels, calendar labels, page names and small embedded screenshot were covered. PNG ancillary metadata was removed. Aggregate figures remain real at the author's explicit request, so the image is not fully synthetic or a guarantee of anonymization. It is a visual reference only, not a pixel-exact archival capture or evidence that the public version produced these results. The unredacted source and its repository history are not included. Automated text checks cannot audit pixels; this specific image was visually reviewed.

## Live execution boundary

Executable examples and fixtures are synthetic; the authorized visual reference is the explicit exception for retained aggregate figures. A configured live connector retrieves real data. Normalization does not anonymize real issue IDs or categorical values. Keep live output private and apply organizational access and retention controls. Do not treat authorization for this one image as permission to publish other live output. Minimize selected fields at the query source. The field allowlist is a schema contract, not a data-loss-prevention system.

Store real credentials outside Git, use the least privilege sufficient for the selected dataset, verify the HTTPS API origin independently and rotate credentials according to organizational policy. A Power Query parameter and a local PBIX are not a vault. Local previews, host errors, tracing and gateway logs can still contain sensitive information even when connector diagnostics are sanitized.

The live adapter blocks unknown paths and redirects and checks a basic HTTPS origin shape. It cannot decide whether a user-entered origin is trustworthy. No credentials are used by the offline demo or tests. No live request was made during preparation of this edition.

`.gitignore` reduces accidental additions of local configuration, Power BI containers, secrets, logs and runtime evidence. It does not protect files already tracked, arbitrary renamed files or screenshots placed elsewhere. Inspect every staged file and run an approved secret scanner before publication. The included artifact checker is a limited pattern-based guardrail, not a comprehensive secret scanner.

## Safe troubleshooting

Inspect error codes, delivery mode and row counts. Do not add tokens, tenant addresses, raw rows, signed URLs or provider error bodies to public issues. Reproduce with synthetic fixtures. If a real secret is disclosed, revoke it and follow the provider's removal procedure; deleting a file in a later commit is insufficient.
