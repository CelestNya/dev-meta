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
| `cc-connectivity` | 手动 / 相关文件变更 | 探测 CommandCode API（`api.commandcode.ai`）从 GitHub Actions runner 的可达性与鉴权 |

## 约定

- 笔记用 Markdown，一条经验一个文件，文件名 `YYYYMMDD-主题.md`
- 涉及凭据的内容一律走 Actions Secrets，永不入库
