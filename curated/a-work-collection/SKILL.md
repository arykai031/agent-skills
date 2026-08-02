---
name: a-work-collection
description: 建立可复用的收口目录骨架（a_work）——交付物唯一出口。含 AGENTS.md 行为规范（回写策略/索引格式/命名规范/禁止事项）、INDEX.md 双链索引、目录用途划分。当用户提到"收口目录""交付物目录""outputs 重构""目录骨架""目录管理方案"时使用。
---

# 收口目录骨架（a_work）

## 触发条件

- 用户要建/重构"收口目录""交付物出口""输出目录"
- 用户提到目录骨架、归档规范
- 新机器/WSL 搭建统一目录结构

## 核心原则

1. **分层看职责边界，不看目录数量**：配置层（../.config 等工具自管）、项目层（../projects，git 备份）、交付层（a_work，唯一出口）、规范层（SOUL.md 管行为）
2. **目录价值在边界不在数量**：不需要用户目录级索引、不需要"超级目录"
3. **各走各路**：配置靠工具恢复、仓库靠 git push、交付物靠 tar+INDEX、行为靠 SOUL.md

## 目录结构

```
~/a_work/              # 交付物唯一出口（排序置顶：a 开头）
├── AGENTS.md          # 行为规范：回写策略/索引格式/命名规范/禁止事项
├── INDEX.md           # 双链索引（Obsidian 格式）
├── research/          # 调研报告、信息收集 —— 长期保留
├── docs/              # 正式文档、方案、规范 —— 长期保留
├── scripts/           # 脚本、自动化工具 —— 长期保留
├── data/              # 数据导出文件 —— 按需清理
└── temp/              # 临时文件 —— 每周清理
```

**配套目录**：git 仓库放 `../projects/<repo>/`（不塞进 a_work），项目级 AGENTS.md 放各仓库内。

## 落地步骤

1. 建目录：`mkdir -p ~/a_work/{research,docs,scripts,data,temp}`
2. 写入 AGENTS.md（模板见 `templates/AGENTS.md`）
3. 写入 INDEX.md（模板见 `templates/INDEX.md`）
4. 迁移现有交付物：按类型归类到对应子目录，核对实际文件后登记 INDEX
5. 硬编码引用检查：移动/改名目录前，`search_files` 搜旧路径（如 `outputs`），逐处更新脚本、skill、memory 中的引用

## 关键细节

- 索引用 **Obsidian 双链**：`[[文件名]]` 或 `[[子目录/文件名|显示名]]`
- 状态生命周期：`✅ 使用中` → `📦 已归档` → `🗑️ 已废弃`（归档用标记不用物理删除）
- 命名：文档 kebab-case、脚本 snake_case、时间敏感加 `YYYYMMDD-` 前缀；禁止空格/中文文件名
- 自动生成文件（如 backup-latest.json）若被脚本硬编码引用，单独登记"自动生成勿动"，不迁移
- AGENTS.md 与 INDEX.md 互相双链，Obsidian 内可互跳

## 陷阱

- 改名/迁移前必须检查硬编码引用（备份脚本、cron、skill 常写死旧路径），漏改会断链路
- 不要物理删除已归档文件，用状态标记
- 不要在 a_work 里放 git 仓库（→ ../projects/）、密钥（→ Bitwarden）
- 只写文件不登记 INDEX = 没写，每次写入必须同步更新索引
