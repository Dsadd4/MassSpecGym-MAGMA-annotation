# Scope

This is a public handoff of the existing MassSpecGym MAGMa v8 annotation
generator. Read README.md, docs/KNOWN_ISSUES.md, and docs/PACKAGING.md before work.

- Do not silently change fragmentation, mass matching, atom indexing, or output
  semantics. Algorithm repairs need explicit documentation and meaningful checks.
- Keep source_manifest.json as the immutable original snapshot record.
- Keep complete datasets, outputs, credentials, and local/remote machine access
  configuration outside Git. Use the synthetic examples only for interface checks.
- The generator has no resume support. Never restart it against an output that
  must be preserved; use a new output directory.
- Run full annotation or dataset scans on an allocated compute node, with bounded
  workers, saved configuration, logs, and an explicit output path.
- Record resolved operational problems in docs/ and link the note here.

Packaging and operational entry point: [docs/PACKAGING.md](docs/PACKAGING.md).
