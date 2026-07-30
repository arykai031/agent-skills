# 常见问题

## curated/ 和 community/ 有什么区别？

| | curated/ | community/ |
|---|---|---|
| **来源** | 你自己开发的技能 | 从 SkillHub 安装的社区技能 |
| **版本控制** | ✅ 完全受控 | 快照，锁版本 |
| **修改** | 随意 | 不建议修改，如需修改先 fork 到 curated |

## 技能怎么安装到 QwenPaw？

```bash
# 方式1：软链（推荐，保持仓库为源）
ln -s /path/to/agent-skills/curated/<skill> <workspace>/skills/

# 方式2：复制
cp -r /path/to/agent-skills/curated/<skill> <workspace>/skills/
```

## 想修改社区技能怎么办？

1. 把社区技能复制到 `curated/` 下
2. 修改 `source-lock.json` 标注来源
3. 在 `SKILL.md` 中记录修改内容
