# xz-source 工程项目清单

**更新时间**: 2026-05-20
**数据来源**: D:\TRS_BJ\xz-source 目录扫描
**过期提醒**: 此事实性数据可能随工程变更而失效，超过 30 天需重新核实

## 统计概览

| 分类 | 数量 | 占比 |
|------|------|------|
| **工程总数** | 36 | 100% |
| 后端 Java 项目 | 25 | 69% |
| 前端项目 | 9 | 25% |
| 工具包项目 | 2 | 6% |
| **有 MySQL 依赖** | 21 | 58% |
| **无 MySQL 依赖** | 4 | 11% |
| **需迁移改造** | 21 | 58% |

---

## 一、有 MySQL 依赖的后端项目（需迁移改造，21 个）

**重要发现**：经深入检查（验证配置文件、pom.xml、实际代码），**21 个后端 Java 项目有 MySQL 依赖**，需要纳入迁移计划。

### 1.1 核心 API 服务（5 个）

| # | 工程名称 | 功能描述 | 数据库 | 主要技术栈 |
|---|---------|---------|--------|-----------|
| 1 | `xz_yq_server` | 西藏舆情 API 服务 | common_search_prod | Spring Boot, WebSocket |
| 2 | `xz_local_server` | 西藏本地服务器 | 8.0.15 | Spring Boot, Flyway |
| 3 | `xz_internet_server` | 西藏互联网服务器 | - | Spring Boot |
| 4 | `xz_leader_view_server` | 西藏领导视图服务器 | - | Spring Boot |
| 5 | `xz-knowledge-server` | 西藏知识库后端 | - | Spring Boot |

### 1.2 数据接收与处理服务（10 个）

| # | 工程名称 | 功能描述 | 数据库 | 主要技术栈 |
|---|---------|---------|--------|-----------|
| 1 | `stream_keywords_search` | 事件计算服务-检索预警 | common_search_dev | Spring Boot, 消息队列 |
| 2 | `xz_home_server` | 西藏门户后端登录 | xz_home_data | Spring Boot WebFlux |
| 3 | `xz-alertsens-receive` | 西藏预警敏感信息接收 | wxb_yqzx_dev | Spring Boot |
| 4 | `xz-event-handle` | 西藏事件处理 | xz_data_test | Spring Boot |
| 5 | `xz-event-msg` | 西藏事件消息 | xz_yq_server_test | Spring Boot |
| 6 | `xz-hybaseResult-receive` | 西藏 Hybase 结果接收 | xz_data_test | Spring Boot |
| 7 | `xz-internet-toolServer` | 西藏内外网工具服务器 | internet_tool_data | Spring Boot |
| 8 | `xz-local-stream` | 西藏本地流媒体 | xz_sd | Spring Boot |
| 9 | `xz-media-search` | 西藏媒体搜索 | wxb_yqzx_dev | Spring Boot |
| 10 | `xz-snapshot-receive` | 西藏快照接收 | xz_data_test | Spring Boot |

### 1.3 其他后端服务（6 个）

| # | 工程名称 | 功能描述 | 数据库 | 主要技术栈 |
|---|---------|---------|--------|-----------|
| 1 | `xz_accuse_server` | 西藏举报服务 | xz_accuse | Spring Boot |
| 2 | `xz_leader_view_socket` | 西藏领导视图 Socket | xz_home_data_test | Spring Boot, WebSocket |
| 3 | `xz_video_handle` | 西藏视频处理 | xz_data_test | Spring Boot |
| 4 | `trs-cloud-snapshot-rest` | 云快照 REST 服务 | - | Spring Boot, Flyway |
| 5 | `trs-cloud-soundres-receive` | 云音频资源接收服务 | xz_data_test | Spring Boot |
| 6 | `trs-cloud-xz-userMsg-receiver` | 云用户消息接收服务 | xz_data_test | Spring Boot |

**迁移优先级建议**：
- **P0（首批验证）**: `xz_yq_server`, `xz_local_server`（已明确使用 MySQL 8.0.15 + Flyway）
- **P1**: 其他使用 Flyway 的项目 + 核心业务服务
- **P2**: 其他接收类、工具类服务

---

## 二、无 MySQL 依赖的后端项目（4 个）

**无需迁移改造**：这 4 个项目不依赖 MySQL 数据库，主要是消息队列、WebSocket 等中间件类型服务。

| # | 工程名称 | 功能描述 | 主要技术栈 |
|---|---------|---------|-----------|
| 1 | `xz_log_stat` | 西藏日志收集和消息推送 | Spring Boot, RocketMQ |
| 2 | `xz_accuse_sync_server` | 西藏举报同步服务 | Spring Boot |
| 3 | `xz_yq_proxy_server` | 西藏网闸代理服务器 | Spring Boot |
| 4 | `xz_yq_websocket` | 西藏 WebSocket 服务 | Spring Boot, WebSocket |

**共同特征**：无数据源配置，主要功能是消息转发/代理/推送。

---

## 三、前端项目（无需数据库改造，9 个）

| # | 工程名称 | 功能描述 | 技术栈 |
|---|---------|---------|--------|
| 1 | `xz_home_web` | 西藏门户系统前端 | Vue 2.5.13, iView, ECharts |
| 2 | `xz-knowledge-web` | 西藏知识库前端 | Vue 2.5.13, iView, ECharts |
| 3 | `xz-internet-toolWeb` | 西藏内外网传输工具前端 | Vue 2.5.13, iView |
| 4 | `xz_jb_internet_web` | 西藏互联网界面 | Vue |
| 5 | `xz_jb_403_web` | 西藏 403 错误页面 | Vue |
| 6 | `xz_leader_view_web` | 西藏领导视图前端 | Vue |
| 7 | `xz_local_web` | 西藏本地前端 | Vue |
| 8 | `xz_yq_web` | 西藏舆情前端 | Vue |
| 9 | `xz-yq_web` | 西藏网闸前端 | Vue |

**共同特征**：100% 使用 Vue 2.x，无数据库依赖，不在迁移范围。

---

## 四、工具包项目（2 个）

| # | 工程名称 | 功能描述 |
|---|---------|---------|
| 1 | `db-migration-toolkit` | MySQL → 瀚高改造方法论工具包（当前仓库） |
| 2 | `bes-migration-toolkit` | BES 迁移工具包 |

---

## 五、中间件识别

基于工程名称与功能描述，识别出以下中间件类型项目：

| 类型 | 工程名称 |
|------|---------|
| **消息队列** | `stream_keywords_search`, `trs-cloud-mq-common` |
| **网关服务** | `trs-cloud-gateway-client`, `xz_yq_proxy_server` |
| **WebSocket 服务** | `xz_leader_view_socket`, `xz_yq_websocket` |
| **API 网关** | `xz_internet_server`, `xz_yq_server` |

---

## 六、技术栈分布

### 后端技术栈
- **框架**: Spring Boot (100%)
- **数据访问**: MyBatis / JPA / JdbcTemplate
- **数据库迁移**: Flyway (19%，即 4/21 个有 MySQL 依赖的项目)
- **实时通信**: WebSocket (16%, 4 个项目)
- **响应式**: WebFlux (4%, 1 个项目)

### 前端技术栈
- **框架**: Vue 2.x (100%)
- **UI 库**: iView (33%, 3 个项目)
- **图表**: ECharts (22%, 2 个项目)
- **构建**: Webpack (100%)

---

## 七、数据库迁移现状

| 指标 | 数量/占比 |
|------|----------|
| 使用 Flyway 进行版本管理 | 4 个项目 |
| 明确使用 MySQL 8.0.15 | 2 个项目 |
| **有 MySQL 依赖的后端项目** | **21 个项目 (84%)** |
| 已有标准化迁移流程 | 19% 的有 MySQL 依赖项目 |

**关键发现**：
1. **迁移改造范围明确**：21 个后端项目有 MySQL 依赖，需纳入迁移计划
2. **迁移工具使用率较低**：仅 19% 的有 MySQL 依赖项目使用 Flyway，大部分项目需补充迁移脚本
3. **版本统一**：核心项目使用 MySQL 8.0.15，版本一致性好

---

## 附录：工程路径清单

### 有 MySQL 依赖的后端项目路径（21 个）
```
# 核心 API 服务
D:\TRS_BJ\xz-source\xz_yq_server
D:\TRS_BJ\xz-source\xz_local_server
D:\TRS_BJ\xz-source\xz_internet_server
D:\TRS_BJ\xz-source\xz_leader_view_server
D:\TRS_BJ\xz-source\xz-knowledge-server

# 数据接收与处理服务
D:\TRS_BJ\xz-source\stream_keywords_search
D:\TRS_BJ\xz-source\xz_home_server
D:\TRS_BJ\xz-source\xz-alertsens-receive
D:\TRS_BJ\xz-source\xz-event-handle
D:\TRS_BJ\xz-source\xz-event-msg
D:\TRS_BJ\xz-source\xz-hybaseResult-receive
D:\TRS_BJ\xz-source\xz-internet-toolServer
D:\TRS_BJ\xz-source\xz-local-stream
D:\TRS_BJ\xz-source\xz-media-search
D:\TRS_BJ\xz-source\xz-snapshot-receive

# 其他后端服务
D:\TRS_BJ\xz-source\xz_accuse_server
D:\TRS_BJ\xz-source\xz_leader_view_socket
D:\TRS_BJ\xz-source\xz_video_handle
D:\TRS_BJ\xz-source\trs-cloud-snapshot-rest
D:\TRS_BJ\xz-source\trs-cloud-soundres-receive
D:\TRS_BJ\xz-source\trs-cloud-xz-userMsg-receiver
```

### 无 MySQL 依赖的后端项目路径（4 个）
```
D:\TRS_BJ\xz-source\xz_log_stat
D:\TRS_BJ\xz-source\xz_accuse_sync_server
D:\TRS_BJ\xz-source\xz_yq_proxy_server
D:\TRS_BJ\xz-source\xz_yq_websocket
```

### 前端项目路径
```
D:\TRS_BJ\xz-source\xz_home_web
D:\TRS_BJ\xz-source\xz-knowledge-web
D:\TRS_BJ\xz-source\xz-internet-toolWeb
D:\TRS_BJ\xz-source\xz_jb_internet_web
D:\TRS_BJ\xz-source\xz_jb_403_web
D:\TRS_BJ\xz-source\xz_leader_view_web
D:\TRS_BJ\xz-source\xz_local_web
D:\TRS_BJ\xz-source\xz_yq_web
D:\TRS_BJ\xz-source\xz-yq_web
```
