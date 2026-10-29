# dev-meta

Agent 开发经验与知识库——个人学习、收集的一切 agent 开发相关内容，按正经项目管理。

## 定位

- **纯文档仓库**：笔记、模式、踩坑记录、评测结论
- **CI 试验田**：GitHub Actions 上的工具链实验（LLM API 联通性、自动化工作流）先在这里验证，成熟后再推广

## 目录结构

```
docs/          主题笔记（按主题分文件）
scripts/       可复用的脚本工具
.github/       CI 工作流
```

## 当前 CI

| Workflow | 触发 | 用途 |
|---|---|---|
| `cc-connectivity` | 手动 / 相关文件变更 | 探测 CommandCode API（`api.commandcode.ai`）从 GitHub Actions runner 的可达性与使用政策 |

## 重要发现（2026-10-30）

**CC 订阅不能从 CI 使用，这是政策不是技术问题。**

联通性探测的实测结论（`scripts/cc-connectivity.sh`）：

1. **网络层完全可达**：Actions runner 到 `api.commandcode.ai` 的 DNS/TLS 全通（<150ms）
2. **鉴权通过**：带 key 的请求进入了业务逻辑层（不是 401）
3. **但被反代理风控识别**：即使完整复刻官方 CLI 的全部特征头（`commandcode-cli/{ver}` UA、`x-command-code-version`、`x-session-id` 等，与 ccproxy `build_headers` 逐字一致），`/alpha/generate` 仍返回：

   > `Proxy use detected. This endpoint only serves CLI. Use Command Code provider API instead. Continued proxying of your subscription violates the TOS and will result in account ban.`

检测维度无法从响应区分（可能是 IP 信誉 / TLS 指纹 / 行为模式，或三者组合）。**不要尝试绕过**——重复触发会真实导致封号。

本地 ccproxy 可用是因为住宅 IP + 完整 CLI 仿冒，但这条警告本身就是风控收紧的信号。

### CI 里需要 LLM 时的替代路径

- 按量付费的正规 API（DeepSeek / GLM 等），月成本几块钱
- CC 错误信息提到的 "provider API" 在公开文档暂无入口（Studio 有 API keys 板块），需要的话去 Studio / Discord 询问

## 约定

- 笔记用 Markdown，一条经验一个文件，文件名 `YYYYMMDD-主题.md`
- 涉及凭据的内容一律走 Actions Secrets，永不入库
