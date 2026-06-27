# Example Release Record: v1.0.0 / staging

> Status: success
> This is an example record, not a real production release record.

| Field | Value |
| --- | --- |
| Environment | staging |
| Version | v1.0.0 |
| Image | ghcr.io/shaohan-he/release-demo-service:v1.0.0 |
| Commit SHA | example |
| Build Time | 2026-06-27T00:00:00Z |
| Operator | example |
| Workflow | example |
| Unit Test | success |
| Docker Build | success |
| Trivy Scan | success |
| Kustomize Render | success |
| Kubernetes Rollout | success |
| Smoke Test | success |
| Previous Version | none |

## Rollback Command

```bash
bash scripts/rollback.sh staging --undo
```
