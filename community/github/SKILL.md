---
name: github
version: 1.0.0
description: "GitHub集成工具，支持Issues管理、PR操作、CI运行监控、API查询。适用于代码审查、项目跟踪、自动化工作流。"
tags: [管理GitHub Issues和Pull Requests, 监控CI/CD运行状态, 查询仓库信息和统计数据, 自动化GitHub工作流程]
tags: [git, github, version-control, ci-cd]
difficulty: beginner
requires: gh CLI
---

# GitHub Skill

使用 `gh` CLI与GitHub交互。在非git目录下时，必须指定 `--repo owner/repo`，或直接使用URL。

## 安装

### macOS
```bash
brew install gh
```

### Linux
```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

### Windows
使用 [scoop](https://scoop.sh/) 或 [winget](https://docs.microsoft.com/en-us/windows/package-manager/winget/):
```bash
scoop install gh
# 或
winget install --id GitHub.cli
```

### 认证
```bash
gh auth login
```

## Issues 管理

### 列出 Issues
```bash
# 列出所有开放的Issues
gh issue list --repo owner/repo

# 列出指定状态的Issues
gh issue list --repo owner/repo --state closed

# 按作者过滤
gh issue list --repo owner/repo --author username

# 按标签过滤
gh issue list --repo owner/repo --label bug

# 限制数量
gh issue list --repo owner/repo --limit 20
```

### 创建 Issue
```bash
# 基本创建
gh issue create --repo owner/repo --title "Issue标题" --body "Issue描述"

# 指定标签和受托人
gh issue create --repo owner/repo \
  --title "修复登录bug" \
  --body "详细描述问题..." \
  --label bug,priority:high \
  --assignee username
```

### 查看 Issue
```bash
# 查看Issue详情
gh issue view 123 --repo owner/repo

# 查看评论
gh issue view 123 --repo owner/repo --comments
```

### 关闭/重新打开 Issue
```bash
# 关闭
gh issue close 123 --repo owner/repo --comment "已修复"

# 重新打开
gh issue reopen 123 --repo owner/repo --comment "需要更多信息"
```

## Pull Requests 管理

### 创建 PR
```bash
# 从当前分支创建PR
gh pr create --repo owner/repo --title "PR标题" --body "PR描述"

# 指定目标分支
gh pr create --repo owner/repo \
  --base main \
  --head feature-branch \
  --title "新功能" \
  --body "实现细节..."

# 草稿PR
gh pr create --repo owner/repo --title "WIP: 新功能" --draft
```

### 查看 PR
```bash
# 列出PR
gh pr list --repo owner/repo

# 查看PR详情
gh pr view 55 --repo owner/repo

# 查看PR的变更文件
gh pr diff 55 --repo owner/repo

# 查看PR的评论
gh pr view 55 --repo owner/repo --comments
```

### 检查 CI 状态
```bash
# 检查PR的CI状态
gh pr checks 55 --repo owner/repo

# 查看某个检查的详情
gh pr checks 55 --repo owner/repo --watch
```

### 合并 PR
```bash
# 合并并删除分支
gh pr merge 55 --repo owner/repo --squash --delete-branch

# 仅合并，不删除分支
gh pr merge 55 --repo owner/repo --merge

# 放弃PR（关闭但不合并）
gh pr close 55 --repo owner/repo
```

## CI/CD 运行监控

### 列出 Workflow 运行
```bash
# 列出最近的运行
gh run list --repo owner/repo --limit 10

# 列出指定Workflow的运行
gh run list --repo owner/repo --workflow "CI.yml" --limit 20

# 只看失败的运行
gh run list --repo owner/repo --status failure --limit 10
```

### 查看运行详情
```bash
# 查看运行概览
gh run view 1234567890 --repo owner/repo

# 查看失败的日志
gh run view 1234567890 --repo owner/repo --log-failed

# 查看完整的日志
gh run view 1234567890 --repo owner/repo --log

# 实时跟踪运行
gh run watch 1234567890 --repo owner/repo
```

### 重试运行
```bash
# 重试失败的运行
gh run rerun 1234567890 --repo owner/repo

# 取消运行
gh run cancel 1234567890 --repo owner/repo
```

## 高级 API 查询

`gh api` 命令可以访问其他子命令无法提供的数据。

### 获取仓库信息
```bash
# 获取仓库基本信息
gh api repos/owner/repo

# 获取特定字段
gh api repos/owner/repo --jq '.name, .stargazers_count, .language'

# 获取仓库统计数据
gh api repos/owner/repo/stats/contributors
```

### 获取 PR 信息
```bash
# 获取PR的特定字段
gh api repos/owner/repo/pulls/55 --jq '.title, .state, .user.login, .mergeable'

# 获取PR的提交
gh api repos/owner/repo/pulls/55/commits --jq '.[].sha, .[].commit.message'
```

### 获取分支信息
```bash
# 列出所有分支
gh api repos/owner/repo/branches --jq '.[].name'

# 获取受保护分支
gh api repos/owner/repo/branches/protection/main
```

### 搜索仓库
```bash
# 按关键词搜索
gh api search/repositories?q=tensorflow --jq '.items[] | .full_name'

# 按语言搜索
gh api search/repositories?q=language:python --jq '.items[] | .full_name'
```

## JSON 输出与过滤

大多数命令支持 `--json` 输出结构化数据，可以使用 `--jq` 进行过滤：

```bash
# 获取Issues的编号和标题
gh issue list --repo owner/repo --json number,title --jq '.[] | "\(.number): \(.title)"'

# 获取PR的作者和状态
gh pr list --repo owner/repo --json number,title,state,author --jq '.[] | "\(.number) by \(.author.login): \(.title) (\(.state))"'

# 获取仓库的Star数和Fork数
gh api repos/owner/repo --jq '"Stars: \(.stargazers_count), Forks: \(.forks_count)"'
```

## 常用工作流

### 工作流1: 审查PR
```bash
# 1. 查看开放的PR
gh pr list --repo owner/repo

# 2. 查看特定PR的变更
gh pr view 55 --repo owner/repo
gh pr diff 55 --repo owner/repo

# 3. 检查CI状态
gh pr checks 55 --repo owner/repo

# 4. 如果通过，合并PR
gh pr merge 55 --repo owner/repo --squash --delete-branch
```

### 工作流2: 调试CI失败
```bash
# 1. 找到失败的运行
gh run list --repo owner/repo --status failure --limit 1

# 2. 查看失败的日志
gh run view <run-id> --repo owner/repo --log-failed

# 3. 修复问题后，重试运行
gh run rerun <run-id> --repo owner/repo
```

### 工作流3: 批量管理Issues
```bash
# 1. 查找所有未处理的bug
gh issue list --repo owner/repo --label bug --state open

# 2. 批量关闭已解决的Issues
gh issue close 123 --repo owner/repo --comment "已在v1.2.0中修复"
gh issue close 124 --repo owner/repo --comment "重复问题"
```

## 配置

### 设置默认仓库
```bash
gh repo set-default owner/repo
# 之后可以省略 --repo 参数
gh issue list
```

### 设置编辑器
```bash
gh config set editor vim
# 或
gh config set editor code
```

### 查看/设置配置
```bash
# 查看所有配置
gh config list

# 设置Git配置
gh config set git_protocol ssh
gh config set prompt disabled
```

## 常见问题

### Q: 如何处理认证失败？
A: 重新进行认证：
```bash
gh auth logout
gh auth login
```

### Q: 如何查看当前登录的用户？
```bash
gh auth status
```

### Q: 如何在非git目录中使用gh命令？
A: 使用 `--repo owner/repo` 指定仓库：
```bash
gh issue list --repo owner/repo
```

### Q: 如何导出Issue为CSV？
```bash
gh issue list --repo owner/repo --json number,title,state,author,labels | jq -r '.[] | [.number, .title, .state, .author.login] | @csv' > issues.csv
```

## 参考资源

- [GitHub CLI 文档](https://cli.github.com/manual/)
- [GitHub API 文档](https://docs.github.com/en/rest)
- [gh 扩展](https://github.com/github/gh-extensions)
