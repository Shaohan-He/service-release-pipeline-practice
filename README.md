# service-release-pipeline-practice

业务服务 CI/CD 发布流水线实践项目。项目用一个轻量 FastAPI 服务串起 GitHub Actions、Docker、Trivy、Kubernetes、Kustomize、smoke test、canary、rollback 和 release record，用于展示一个业务服务从代码提交到安全发布上线的完整流程。

这是个人 Kubernetes 测试环境中的企业发布流程实践。`production` 是模拟生产环境 namespace，不代表真实生产环境。真实生产环境还需要进一步接入权限控制、审计、密钥管理、监控告警、变更审批和更完整的应急流程。

## 项目解决的问题

- 代码提交后如何自动运行单元测试和构建检查。
- 镜像如何按 `v1.0.0`、`v1.1.0`、commit sha 进行追踪。
- 镜像发布前如何进行 Trivy 安全扫描。
- dev、staging、production 三套环境如何用 Kustomize 管理差异。
- staging 如何自动部署，production 如何通过 GitHub Environment 手动审批。
- 发布后如何执行健康检查、smoke test、灰度验证和异常回滚。
- 发布结果如何形成可归档的 release record。

## 技术栈

GitHub Actions、Docker、Kubernetes、Kustomize、Shell、Trivy、kubectl、Python FastAPI。

本项目不使用 Helm、Jenkins、Argo CD、Argo Rollouts、Terraform、数据库、中间件或 PVC/PV，避免把发布流程演示变成复杂平台搭建。

## 发布流程图

```text
code push / PR
      |
      v
CI: pytest + docker build + kustomize render
      |
      v
Build image: version tag + commit sha tag
      |
      v
Trivy scan: HIGH/CRITICAL fail
      |
      v
staging deploy -> rollout status -> smoke test
      |
      v
production approval
      |
      v
canary deploy -> canary smoke test
      |
      v
stable production deploy -> smoke test
      |
      v
release record
      |
      v
rollback if needed
```

## 目录结构

```text
.
├── .github/workflows/          # CI、镜像构建、staging 部署、production 提升
├── app/                        # FastAPI 示例服务、测试、Dockerfile
├── k8s/base/                   # 通用 Deployment、Service、Ingress
├── k8s/overlays/               # dev / staging / production 差异配置
├── k8s/overlays/production/canary/
├── scripts/                    # 构建、部署、smoke test、回滚、发布记录脚本
├── docs/                       # 中文流程文档
├── release-records/            # 发布记录说明和示例
├── Makefile
└── .env.example
```

## 核心功能

- FastAPI 服务暴露 `/healthz`、`/readyz`、`/version`、`/api/order`。
- pytest 覆盖正常接口和 `fail=true` 异常接口。
- Docker 镜像支持 build args 注入版本、commit sha、环境和构建时间。
- Kustomize 管理 dev、staging、production 和 production canary。
- GitHub Actions CI 不依赖真实集群或 secrets。
- staging 支持自动部署；没有 `KUBE_CONFIG_DATA` 时只做渲染检查并给出说明。
- production 使用 GitHub Environment 手动审批，先 canary 后 stable。
- 脚本支持本地构建、部署、smoke test、回滚和 release record 生成。

## 本地运行方式

```bash
cd service-release-pipeline-practice
python -m venv .venv
source .venv/bin/activate
pip install -r app/requirements.txt
cd app
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

访问：

```bash
curl http://localhost:8000/healthz
curl http://localhost:8000/readyz
curl http://localhost:8000/version
curl http://localhost:8000/api/order
curl -i "http://localhost:8000/api/order?fail=true"
```

运行测试：

```bash
make test
```

## Docker 构建方式

```bash
make docker-build TAG=v1.0.0 VERSION=v1.0.0 GIT_SHA=local
docker run --rm -p 8000:8000 release-demo-service:local
```

也可以直接运行：

```bash
bash scripts/build-image.sh ghcr.io/shaohan-he/release-demo-service v1.0.0 local v1.0.0
```

Dockerfile 使用 `python:3.12-slim`，只复制 `requirements.txt` 和 `main.py`，并使用非 root 用户运行服务。

## Kubernetes 部署方式

先确认 kubectl 可以访问测试集群：

```bash
kubectl version
kubectl config current-context
```

渲染检查：

```bash
kubectl kustomize k8s/overlays/dev
kubectl kustomize k8s/overlays/staging
kubectl kustomize k8s/overlays/production
kubectl kustomize k8s/overlays/production/canary
```

部署：

```bash
bash scripts/deploy.sh dev
bash scripts/deploy.sh staging
bash scripts/deploy.sh production
```

如果没有 Ingress Controller，可以用 port-forward 演示：

```bash
kubectl -n service-staging port-forward svc/release-demo-service 8080:80
bash scripts/smoke-test.sh staging http://localhost:8080
```

如果本地没有 kubectl，可以按 Kubernetes 官方文档安装，或先用 `pytest`、`docker build`、脚本阅读和 GitHub Actions 的 render 检查进行演示。

## 环境说明

| 环境 | Namespace | Replicas | 镜像策略 | 部署策略 |
| --- | --- | ---: | --- | --- |
| dev | `service-dev` | 1 | `dev-latest` | 本地开发或手动部署 |
| staging | `service-staging` | 2 | `staging-latest` 或 commit sha | main 合并后自动部署 |
| production | `service-production` | 3 | 明确版本号或 digest | GitHub Environment 手动审批 |

production 不使用 `latest`。模拟 production namespace 只用于个人测试环境中的发布流程演示。

## GitHub Actions 流程说明

- `ci.yml`：push 和 pull request 触发，运行 pytest、docker build、Kustomize render。
- `build-image.yml`：main 分支、`v*` tag 或手动触发，构建镜像，推送版本 tag 和 commit sha tag，执行 Trivy 扫描。
- `deploy-staging.yml`：镜像构建成功后或手动触发，存在 `KUBE_CONFIG_DATA` 时部署 staging，否则只做 render 检查。
- `promote-production.yml`：手动触发，使用 `environment: production` 等待审批，先部署 canary，验证通过后部署 stable，并生成 release record。

需要配置的 Secret：

```text
KUBE_CONFIG_DATA
```

该值是 kubeconfig 的 base64 内容。没有该 secret 时，部署类 workflow 不会失败，会输出说明并保留配置渲染能力。

production 手动审批需要在 GitHub 仓库 `Settings -> Environments -> production` 中配置 reviewer。

## 镜像 Tag 规范

- `v1.0.0`、`v1.1.0`：用于明确版本发布。
- commit sha：用于精确追踪一次代码提交对应的镜像。
- `dev-latest`：仅用于 dev 默认配置。
- `staging-latest`：仅用于 staging 默认配置或预发测试。

production 不使用 `latest`，因为 `latest` 无法直接表达代码版本、构建时间和回滚目标。上线后可以通过 `/version` 验证 `version`、`git_sha`、`image_tag` 和 `environment`。

## Trivy 安全扫描说明

`build-image.yml` 使用 Trivy 扫描镜像，`HIGH` 和 `CRITICAL` 级别漏洞会导致 workflow 失败。示例项目使用 `ignore-unfixed: true`，避免没有修复版本的基础镜像漏洞阻塞所有演示，但真实生产环境应结合组织策略调整。

## Staging 自动部署

staging 代表预发环境。镜像构建和扫描完成后，如果仓库配置了 `KUBE_CONFIG_DATA`，`deploy-staging.yml` 会：

1. 应用 `k8s/overlays/staging`。
2. 等待 `rollout status`。
3. 执行 smoke test。
4. 生成 release record artifact。

## Production 手动审批

production 是模拟生产环境 namespace。`promote-production.yml` 使用 GitHub Environment 的 `production` 环境，触发后先等待 reviewer 审批。审批通过且存在 `KUBE_CONFIG_DATA` 时，流程会部署 canary，验证通过后再更新 stable deployment。

## Smoke Test 说明

脚本检查：

- `/healthz`
- `/readyz`
- `/version`
- `/api/order`

URL 模式：

```bash
bash scripts/smoke-test.sh staging http://localhost:8080
```

port-forward 模式：

```bash
bash scripts/smoke-test.sh staging
```

任一接口失败都会返回非 0，适合放进发布流水线。

## 灰度发布说明

本项目使用 Kubernetes 原生资源模拟轻量 canary：

- stable：`release-demo-service` Deployment，label `track: stable`。
- canary：`release-demo-service-canary` Deployment，label `track: canary`。
- canary Service：`release-demo-service-canary`，只选中 canary Pod。

canary 验证通过后，流水线更新 stable Deployment。验证失败时不更新 stable，可删除 canary 资源。

## 回滚流程说明

Kubernetes 原生回滚：

```bash
bash scripts/rollback.sh production --undo
```

指定镜像 tag 回滚：

```bash
bash scripts/rollback.sh production v1.0.0
```

回滚后必须执行：

```bash
bash scripts/smoke-test.sh production
```

release record 中会记录上一版本和建议回滚命令。

## Release Record 说明

发布记录用于归档一次发布的核心证据，包括环境、版本、镜像、commit sha、测试结果、扫描结果、rollout 结果、smoke test 结果、上一版本和回滚命令。

生成示例：

```bash
bash scripts/release-record.sh production v1.1.0 abcdef1 success
```

## 项目讲解要点

- 这个项目重点不是业务复杂度，而是发布流程的完整性。
- CI 和部署 workflow 分离，便于在没有真实集群时仍能验证主要配置。
- staging 自动化，production 需要审批，符合常见变更控制思路。
- canary 使用原生 Kubernetes 资源实现，保持轻量和可解释。
- `/version` 和 release record 形成版本追踪闭环。
- 回滚支持 `rollout undo` 和指定 tag 两种方式。

## FAQ

**没有 Kubernetes 集群还能展示吗？**

可以。先运行 pytest、docker build、`kubectl kustomize` 渲染检查，并阅读脚本和 workflow。部署类 workflow 在缺少 `KUBE_CONFIG_DATA` 时会降级为 render 检查。

**为什么不使用 Helm 或 Argo Rollouts？**

项目目标是展示基础发布流程，不是展示平台复杂度。Kustomize 和 Kubernetes 原生资源足够覆盖多环境、canary 和回滚演示。

**为什么 production 不用 latest？**

`latest` 不可追踪，不利于审计和回滚。production 应使用明确版本号、commit sha 或 digest。

**Ingress 必须存在吗？**

不是。Ingress 只是示例配置。没有 Ingress Controller 时使用 `kubectl port-forward` 即可完成 smoke test。

## 后续优化方向

- 使用镜像 digest 固定 production 发布目标。
- 接入 OIDC 和云厂商托管 Kubernetes 的最小权限部署账号。
- 将 Trivy 结果、发布审批和监控截图纳入 release record。
- 增加 Prometheus 指标、日志查询和发布后观察窗口。
- 引入更严格的策略检查，例如 kube-score、conftest 或 Kyverno。
