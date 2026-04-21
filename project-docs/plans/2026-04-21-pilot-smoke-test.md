---
type: plan
title: Pilot 工程烟测清单（整改后首日验证）
created: 2026-04-21
updated: 2026-04-21
owner: gloryman
status: pending
---

# Pilot 工程烟测清单

> 用途：本工具包从 GaussDB pivot 到瀚高 v4.1.5 的整改完成后，由 Pilot 工程 `stream_keywords_search` 执行的**首日烟测**，确认整改后的工具包可执行、SOP 可跑通。
>
> 本清单**不替代**五段式 SOP 本身的执行，仅做"工具包交付物可用性"验证。

## 前置条件

- 本工具包 v0.2.0 已整改完成（git tag `v0.2.0`）
- Pilot 工程目录：`/Users/cy/MyWorkFactory/workspace/xz-source/stream_keywords_search`
- 瀚高 v4.1.5 测试环境连接信息已获取（至少可 `psql` 连通）
- Pilot 负责人拥有目标库建库 owner 权限（C9 验证）

## 烟测步骤

### S1: 工具包基本状态

```bash
cd /Users/cy/MyWorkFactory/workspace/xz-source/db-migration-toolkit
cat VERSION                   # 期望：0.2.0
git log --oneline -5          # 期望：最新 commit 涉及 highgo 整改
git tag -l "v0.2.0"           # 期望：存在
```

### S2: 文档结构与引用完整性

```bash
# 扩展 regex 残留扫描（排除刻意保留的对比语境文件）
grep -rn -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式|gaussdbjdbc|huawei\.gauss|jdbc:gaussdb" \
  --include="*.md" --include="*.yaml" --include="*.yml" \
  --exclude="2026-04-21-why-b-compat-mode.md" \
  --exclude="2026-04-21-pivot-to-highgo.md" \
  --exclude="CHANGELOG.md" \
  .
# 期望：仅有标注为"与 GaussDB B 模式对比说明"等刻意保留行；无纯术语残留
```

### S3: Skill 软链到 Pilot 工程

```bash
cd /Users/cy/MyWorkFactory/workspace/xz-source/stream_keywords_search
mkdir -p .claude/skills
cd .claude/skills
for s in db-migration-baseline db-migration-sql-scan db-migration-test-gap \
         db-migration-dialect-rewrite db-migration-schema-convert db-migration-verify; do
  [ ! -L "$s" ] && ln -s ../../../db-migration-toolkit/skills/$s .
done
ls -la
# 期望：6 条软链全部存在且指向有效目标
```

在 Claude Code 会话里尝试触发一个 Skill（例如 `/db-migration-baseline`），确认可加载。

### S4: 兼容脚本注入与 7 条冒烟 SQL

```bash
psql "<瀚高连接串>" \
  -f /path/to/db-migration-toolkit/docs/references/highgo-v4.1.5-mysql-compat-functions.sql
# 期望：无 ERROR，多条 NOTICE 显示 function created
```

手工跑 Stage 2 §2.6 的 7 条冒烟 SQL（4 正向 + 3 反向 + 1 版本标记）。

**关键验证**：
- 正向 1（DATE_FORMAT）**必须**通过；不通过立即上升 R-002 风险，评估是否要改脚本实现
- 反向 5/6（IFNULL timestamp、IF int）**必须**报错；若意外通过说明脚本被私自扩展
- `SELECT mysql_compat_version()` 返回 `1.0.0-highgo-v4.1.5-vendor-2026-04-21`（或工具包 bump 后的版本号）

### S5: Flyway 防护语法冒烟（R-018）

按 Stage 3 §3.8 执行 5 类防护语法冒烟 SQL。任一失败记录到 Pilot 工程 `project-docs/fix-issue/` 与工具包 `docs/references/mysql-to-highgo-syntax-mapping.md`。

### S6: Stage 0 skill 可跑通

在 Pilot 工程内调用 Skill `db-migration-baseline`，产出 `project-docs/facts/2026-04-21-db-migration-baseline.md` 骨架。验证：

- 文件生成路径正确
- frontmatter 含 `updated:` 字段
- 内容引用路径指向 `highgo-*` 而非 `gaussdb-*`

### S7: 文档交叉引用可达

从 `docs/2026-04-18-master-plan.md` 随机点 5 个链接，确认全部跳得到真实文件。

### S8: 待确认清单核实

跑 Task 17 Step 17.4 等价命令（排除 plan 文件）：

```bash
cd /Users/cy/MyWorkFactory/workspace/xz-source/db-migration-toolkit
grep -rn -E "⚠️ 待|<待确认-" --include="*.md" --include="*.yml" --include="*.yaml" . \
  | grep -v "2026-04-21-pivot-to-highgo.md"
```

对 C1-C10 逐条核实：

| # | 项 | 暂定值 | Pilot 确认后的真实值 |
|---|----|--------|---------------------|
| C1 | 瀚高版本号 | v4.1.5 | |
| C2 | JDBC 坐标 | `<待确认-瀚高-jdbc-坐标>` | |
| C3 | JDBC URL scheme | `jdbc:highgo://` | |
| C4 | Druid dbType | `postgresql` | |
| C5 | 反引号支持 | 不支持 | |
| C6 | `LIMIT m,n` | 不支持 | |
| C7 | `ON DUPLICATE KEY UPDATE` | 不支持 | |
| C8 | 脚本版权 | 内部使用 | |
| C9 | 注入权限 | 建库 owner | |
| C10 | 脚本适用版本 | 仅 v4.1.5 | |

核实结果回灌到工具包相应文档（PR 到 db-migration-toolkit）。

## 出口标准

烟测结论 = **全通过** 的条件：

- [ ] S1 工具包版本 v0.2.0 已发布
- [ ] S2 残留扫描仅命中刻意保留项
- [ ] S3 6 条软链成功，Skill 可在 Claude Code 中触发
- [ ] S4 正向 4 条冒烟 SQL 全通过，反向 3 条符合预期（报错或预期值）
- [ ] S5 R-018 DDL 防护语法冒烟通过（不支持项已文档化）
- [ ] S6 Stage 0 产出骨架文件正常
- [ ] S7 文档交叉引用全部可达
- [ ] S8 C1-C10 全部核实并回灌

**未通过项处理**：
- S4 正向失败 → 阻塞 Pilot，立即回到工具包修改脚本或文档
- S4 反向意外通过 → 补脚本覆盖列文档，不阻塞
- S5 部分不支持 → 更新 syntax-mapping 状态列，不阻塞
- 其他单项失败 → 修工具包对应文档或 Skill，可继续 Pilot 但需闭环

## 产出物

- 本清单 8 步的实测结果填回本文件
- 发现的问题 PR 到 `db-migration-toolkit`
- 产出 `project-docs/reports/2026-04-XX-pilot-smoke-test-result.md`（Pilot 本地）

## 后续

烟测全通过 → 正式进入 Pilot Stage 0。
