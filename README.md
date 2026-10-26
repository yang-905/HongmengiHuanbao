# 一触青绿

> 一触之间，青绿相随 —— 基于 OpenHarmony 的个人碳足迹记录与碳积分激励应用

## 这是什么

一个**完全单机**的鸿蒙应用：记录日常低碳行为 → 按因子折算减排量 → 累积积分 → 兑换权益/认养树木，配套看板、趋势、任务、徽章、文章与 AI 识图。

数据全部留在手机本地，**不联网、不上传、不需要账号服务器**。

## 仓库结构

| 目录 | 说明 |
| --- | --- |
| `app/` | 鸿蒙端（OpenHarmony ArkTS，Navigation 全局路由），**唯一的运行时程序** |
| `docs/` | 技术方案文档（单机版架构 / 液态玻璃与深色模式） |
| `business-logic-guide/` | 零基础业务讲解手册（单文件 HTML，浏览器直接打开） |
| `tools/` | 文档、图表、主题校验脚本（不参与 App 运行） |

> 早期的 `server/`（若依 Java 后端）、`admin/`（Vue 管理端）、`db/`（MySQL 脚本）已从仓库移除。需要查阅时从 git 历史取回。

## 技术栈

| 项 | 选型 |
| --- | --- |
| 语言 | ArkTS |
| UI | ArkUI 声明式 UI |
| 路由 | Navigation + NavPathStack |
| 结构化存储 | RDB（SQLite，库文件 `carbon.db`，5 张表） |
| 轻量存储 | Preferences（文件 `yichu_qinglv`） |
| 端侧 AI | MindSpore Lite + MobileNetV2（`rawfile/mobilenetv2.ms`） |
| 构建 | Hvigor（`compileSdkVersion 26.0.0` / `compatibleSdkVersion 24`） |
| 包名 | `com.example.yichuqinglv` |

## 环境要求

- DevEco Studio（需 API 26 SDK 以匹配 `compileSdkVersion`，最低运行 API 24）
- 无需 Node、无需数据库、无需任何后端服务

## 运行

1. 用 DevEco Studio 打开 `app/` 目录（不是仓库根目录）
2. 等待 Sync 完成（依赖只有测试框架 hypium）
3. 配置签名：`app/build-profile.json5` → Signing Configs → 自动生成
4. 连接真机或启动模拟器，Run `entry`

命令行构建（Windows）：

```powershell
cd app
.\build-check.ps1
```

产物：`app/entry/build/default/outputs/default/entry-default-signed.hap`

## 数据存在哪

```
App 沙箱
├── databases/carbon.db          # RDB：record / task_claim / article_interact / backup_slot / coupon
└── preferences/yichu_qinglv     # 账号、主题、积分余额、备份元信息
```

首次启动由 `MockStore` 的种子数据初始化因子库、任务、徽章、文章、权益，之后一切写入都在本地。

## 代码导航

| 想找什么 | 去哪 |
| --- | --- |
| 启动入口 | `app/entry/src/main/ets/entryability/EntryAbility.ets` |
| 主框架 / 底部导航 | `app/entry/src/main/ets/pages/Index.ets` |
| 路由注册 | `app/entry/src/main/ets/common/router/PageMap.ets` |
| 页面 | `app/entry/src/main/ets/pages/<业务域>/` |
| 数据门面 | `app/entry/src/main/ets/net/DataSource.ets` |
| 业务逻辑 | `app/entry/src/main/ets/data/LocalStore.ets` |
| SQLite 建表与聚合 | `app/entry/src/main/ets/data/rdb/CarbonRdb.ets` |
| 种子/演示数据 | `app/entry/src/main/ets/data/MockStore.ets` |
| 主题与玻璃效果 | `app/entry/src/main/ets/ui/Theme.ets`、`GlassLight.ets` |

## 技术文档

- [项目目录结构分析](项目目录结构分析.md)：入门版，讲清每个目录是什么模块、用什么技术
- [项目目录与代码索引（详细版）](项目目录与代码索引-详细版.md)：页面/方法/数据表级别的索引
- [答辩逐字稿（8 分钟）](答辩逐字稿-8分钟.md)：路演稿、问答卡、演示操作卡
- [液态玻璃与深色模式方案](docs/液态玻璃与深色模式方案.md)：光照模型、材质参数、深色换血机制
- [OpenHarmony 单机版技术方案](docs/一触青绿_OpenHarmony单机版技术方案_两套.md)：架构选型与数据层设计
- [零基础业务讲解](business-logic-guide/business-logic-guide.html)：浏览器直接打开

## 已知限制

- 备份只有最近一份槽位，且只含记录与券
- RDB 无 schema version，升级改表需手写迁移
- 无自动化测试与 CI
- `module.json5` 仍声明 INTERNET 等权限，代码实际不联网（上架前应清理）
