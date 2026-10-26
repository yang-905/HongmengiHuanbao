# 项目长期记忆

## 用户偏好
- **输出方式**：用户说「输出 XX 方案/内容」时，要求直接呈现在对话回复正文中，不要只写成文件交付（2026-10-23 反馈：「我不是让你做成word」）。文件可作为附加产物保留，但正文必须完整给出内容。
- 语气要求务实、客观、不浮夸，避免夸大或过度理想化的技术描述。

## 项目关键约定
- 项目「一触青绿」：OpenHarmony 单机版碳足迹应用，ArkTS + ArkUI，API 24，Navigation 全局路由。
- 口径：1 kgCO₂e = 10 积分；3000 积分兑 1 棵树；27 项行为因子。
- **存储分层（2026-10-23 RDB 化后）**：业务数据（记录/券/任务领取/文章互动/备份）在 RDB `carbon.db`（`data/rdb/CarbonRdb.ets`，五表六索引、user_key 行级隔离、聚合下推、分页、事务）；Preferences `yichu_qinglv` 只放轻量键值（登录态/种子标记/备份份数与时间/迁移标记 rdb_migrated）。迁移器在 LocalStore.migrateIfNeeded，幂等。
- 范围边界：单设备本地运行，不涉及服务端、网络、账号同步、多端协同、分布式。
- 碳情绪四档（EcoTheme.level，QUOTA=5kg/日）：none(<1kg) / warn(<3kg) / good(<5kg) / eco(≥5kg)；alert 红色档已退役。
- 券有效期：领取后 7×24h（按领取时间起算）；植树证书只由认养植树消耗（treeExchangedPoints）派生。

## 文档产物
- 双方案技术方案 Word：`一触青绿_OpenHarmony技术方案_双方案版.docx`（根目录）；重新生成跑 `tools/gen_tech_doc.py`（python-docx 装在 venv `~/.workbuddy/binaries/python/envs/default`，pip 在其 `Scripts/` 下）。
- 格式规范：正文宋体小四（12pt）1.5 倍行距；标题黑体；A4 页宽文本区 15.4cm（表格列宽合计勿超）。
