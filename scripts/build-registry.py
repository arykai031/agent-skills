#!/usr/bin/env python3
"""从 SKILL.md 自动构建 registry.json"""

import json, os, re, glob
from datetime import datetime, timezone

def extract_description(content):
    """从 SKILL.md frontmatter 提取 description"""
    # 先试多行 literal block: description: |\n  内容
    m2 = re.search(r'^description:\s*(\|)\s*$(.+?)^---', content, re.MULTILINE | re.DOTALL)
    if m2:
        lines = [l.strip() for l in m2.group(2).split('\n') if l.strip()]
        return ' '.join(lines)
    # 单行: description: 拆分prd
    m1 = re.search(r'^description:\s*(\S.*?)$', content, re.MULTILINE)
    if m1:
        return m1.group(1).strip().strip('"').strip("'")
    return ''

def scan_skills(base_dir, namespace):
    skills = []
    for d in sorted(glob.glob(os.path.join(base_dir, '*', ''))):
        name = os.path.basename(os.path.dirname(d))
        md_path = os.path.join(d, 'SKILL.md')
        desc = ''
        if os.path.isfile(md_path):
            with open(md_path) as f:
                desc = extract_description(f.read())
        skills.append({
            'name': name,
            'namespace': namespace,
            'description': desc[:300],
            'path': d
        })
    return skills

def main():
    repo_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(repo_dir)

    skills = []
    skills += scan_skills('curated', 'curated')
    skills += scan_skills('community', 'community')

    registry = {
        'version': 1,
        'description': 'agent-skills 技能注册表 — 机器可读索引',
        'updated': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'skills': skills
    }

    with open('registry.json', 'w') as f:
        json.dump(registry, f, ensure_ascii=False, indent=2)

    print(f'✅ registry.json 已更新 — {len(skills)} 个技能')
    for s in skills:
        print(f'  {s["namespace"]:>10}/{s["name"]:<30} {s["description"][:50]}')

if __name__ == '__main__':
    main()
