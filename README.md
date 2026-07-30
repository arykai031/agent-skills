# agent-skills

> Agent 技能统一管理仓库 — 精选、社区、模板一体化。

将多年沉积在各个 workspace 中的技能**集中管理、版本控制、方便复用**。

## 目录结构

```
agent-skills/
├── curated/        🏆 自研/精选技能（你亲手写的）
├── community/      📦 社区技能本地快照（SkillHub 来源）
├── templates/      📋 技能开发模板
├── scripts/        🔧 管理工具
└── docs/           📖 文档
```

## 快速开始

```bash
# 1. 克隆
git clone https://github.com/arykai031/agent-skills.git

# 2. 查看技能清单
cat SKILLS.md

# 3. 安装某个技能到 QwenPaw workspace
ln -s $(pwd)/curated/<skill-name> <workspace>/skills/
```

## 技能来源说明

| 来源 | 路径 | 说明 |
|------|------|------|
| 🏆 自研 | `curated/` | 你自己开发的技能，可版本控制、可发布到 SkillHub |
| 📦 社区 | `community/` | 从 SkillHub 安装的技能副本，锁定版本防止上游变更 |
