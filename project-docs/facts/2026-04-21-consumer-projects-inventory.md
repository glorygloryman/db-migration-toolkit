---
type: fact
title: xz-source 消费方工程清单
created: 2026-04-21
updated: 2026-04-21
expires_hint: 30d
source: ls /Users/cy/MyWorkFactory/workspace/xz-source/
---

# xz-source 消费方工程清单

> ⚠️ **时效性提示**：本清单为 2026-04-21 扫描快照。若距离 `updated` 字段已超 30 天，请重新扫描 `xz-source/` 目录核对后更新本文件。

## 统计

- 扫描基准：`/Users/cy/MyWorkFactory/workspace/xz-source/`
- 共计：**33 个**消费方工程（不含本工具包自身）
- Skill 接入情况：**0 个已接入**（Pilot 工程 `stream_keywords_search` 待启动）

## 工程清单

| # | 工程名 | 角色推测 | Pilot 标记 | Skill 接入状态 |
|---|--------|---------|-----------|---------------|
| 1 | `stream_keywords_search` | 关键词流检索 | 🚀 **首批 Pilot** | 待接入 |
| 2 | `trs-cloud-snapshot-rest` | 快照 REST 服务 | | 未接入 |
| 3 | `trs-cloud-soundres-receive` | 音频资源接收 | | 未接入 |
| 4 | `trs-cloud-xz-userMsg-receiver` | 用户消息接收 | | 未接入 |
| 5 | `xz-alertsens-receive` | 敏感报警接收 | | 未接入 |
| 6 | `xz-event-handle` | 事件处理 | | 未接入 |
| 7 | `xz-event-msg` | 事件消息 | | 未接入 |
| 8 | `xz-hybaseResult-receive` | HyBase 结果接收 | | 未接入 |
| 9 | `xz-internet-toolServer` | 互联网工具-服务端 | | 未接入 |
| 10 | `xz-internet-toolWeb` | 互联网工具-Web | | 未接入 |
| 11 | `xz-knowledge-server` | 知识库服务端 | | 未接入 |
| 12 | `xz-knowledge-web` | 知识库 Web | | 未接入 |
| 13 | `xz-local-stream` | 本地流 | | 未接入 |
| 14 | `xz-media-search` | 媒体检索 | | 未接入 |
| 15 | `xz-snapshot-receive` | 快照接收 | | 未接入 |
| 16 | `xz-video-handle` | 视频处理 | | 未接入 |
| 17 | `xz_accuse_server` | 举报服务端 | | 未接入 |
| 18 | `xz_accuse_sync_server` | 举报同步服务端 | | 未接入 |
| 19 | `xz_home_server` | 首页服务端 | | 未接入 |
| 20 | `xz_home_web` | 首页 Web | | 未接入 |
| 21 | `xz_internet_server` | 互联网服务端 | | 未接入 |
| 22 | `xz_jb_403_web` | 举报 403 Web | | 未接入 |
| 23 | `xz_jb_internet_web` | 举报互联网 Web | | 未接入 |
| 24 | `xz_leader_view_server` | 领导视图服务端 | | 未接入 |
| 25 | `xz_leader_view_socket` | 领导视图 Socket | | 未接入 |
| 26 | `xz_leader_view_web` | 领导视图 Web | | 未接入 |
| 27 | `xz_local_server` | 本地服务端 | | 未接入 |
| 28 | `xz_local_web` | 本地 Web | | 未接入 |
| 29 | `xz_log_stat` | 日志统计 | | 未接入 |
| 30 | `xz_yq_proxy_server` | 舆情代理服务端 | | 未接入 |
| 31 | `xz_yq_server` | 舆情服务端 | | 未接入 |
| 32 | `xz_yq_web` | 舆情 Web | | 未接入 |
| 33 | `xz_yq_websocket` | 舆情 WebSocket | | 未接入 |

## 使用约定

- **Pilot 标记**：同时仅一个工程打 🚀 表示正在试点；成功验收后置为 ✅
- **Skill 接入状态**：在消费方 `.claude/skills/` 下通过 `ls -la` 确认软链存在
- **角色推测**：仅据工程名推测，非权威分类；Pilot 推进时由工程维护者核实并回填本表

## 字段说明

- 工程名列表来源：`ls /Users/cy/MyWorkFactory/workspace/xz-source/` 命令输出（已剔除 `db-migration-toolkit` 自身）
- **web/socket 类工程**是否需要接入仍待评估——若无数据库访问可直接标"不适用"

## 维护方式

- Pilot 推进到新工程时，在本表更新"Skill 接入状态"列
- 每月月初扫描 `xz-source/` 目录核对新增/删除工程，同步更新 `updated` 字段
- 发现工程角色分类不准，就地修正"角色推测"列
