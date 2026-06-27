# Release Records

release record 用于记录一次发布的核心证据，方便追踪、复盘和回滚。

每条记录建议包含：

- Environment
- Version
- Image
- Commit SHA
- Build Time
- Operator
- Workflow
- Unit Test 结果
- Docker Build 结果
- Trivy Scan 结果
- Kustomize Render 结果
- Kubernetes Rollout 结果
- Smoke Test 结果
- Previous Version
- Rollback Command

生成命令：

```bash
bash scripts/release-record.sh production v1.1.0 abcdef1 success
```

本目录中的 `example-v1.0.0-staging.md` 是示例记录，不代表真实生产发布。
