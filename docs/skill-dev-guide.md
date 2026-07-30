# 技能开发指南

## 一个技能需要什么？

每个技能是一个目录，根目录下必须有 `SKILL.md`：

```
<skill-name>/
├── SKILL.md       # 技能说明、触发条件、能力描述（必选）
├── scripts/       # 辅助脚本（可选）
└── templates/     # 模板文件（可选）
```

## SKILL.md 规范

```markdown
---
name: <技能名称>
description: <触发条件描述 — 告诉 agent 什么时候该用这个技能>
---

# 技能名称

## 能力

- 能力 1
- 能力 2

## 使用方式

## 依赖
```

### 字段说明

| 字段 | 必填 | 说明 |
|------|:---:|------|
| `name` | ✅ | 技能名称，与目录名一致 |
| `description` | ✅ | 一句话描述触发条件，agent 据此判断是否启用 |

### 编写要点

1. **description 要写触发场景**，不要写空泛的描述。例如：
   - ❌ `WMS 相关工具`
   - ✅ `当需要生成 WMS 入库压测数据、校验入库流程时使用`

2. **能力列举要具体**，agent 需要知道你能做什么：
   - ❌ `测试辅助`
   - ✅ `生成批量 SKU 数据、校验入库单状态、模拟波次分配`

## 提交流程

1. 在 `curated/` 下创建技能目录和 `SKILL.md`
2. 运行 `./scripts/validate-skill.sh curated/<skill-name>` 校验格式
3. 运行 `./scripts/build-registry.sh` 更新 registry
4. 提交 PR
