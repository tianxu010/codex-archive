#!/usr/bin/env python3
"""从档案里的 skills.agents.json 索引还原第三方技能到本机。

档案只索引第三方技能的名字与描述，不含源码。本脚本负责把源码找回来：
  1. 用 skills.sh 公共注册表按名字解析出候选仓库（owner/repo + 技能路径）
  2. 每个候选仓库只下载一次 tarball，定位其中的 SKILL.md 目录并安装
  3. 名字对不上的，改用「描述精确匹配」再扫一遍候选仓库

安装目标：~/.codex/skills/（Codex 直接可用），同时镜像一份到 ~/.agents/skills/
（档案原本的第三方技能存放位置）。

用法：
  python3 tools/restore-skills.py            # 只装缺失的
  python3 tools/restore-skills.py --refresh  # 先删掉已装的再重装
  python3 tools/restore-skills.py --list     # 只打印解析结果
"""

import argparse
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.parse
import urllib.request

CODEX = os.environ.get("CODEX_HOME", os.path.expanduser("~/.codex"))
CODEX_SKILLS = os.path.join(CODEX, "skills")
AGENTS_SKILLS = os.path.expanduser("~/.agents/skills")
PROXY = "https://ghfast.top/"          # GitHub 直连慢时的加速通道
BRANCHES = ("main", "master")
EXTRA_REPOS = ("luyufan498/qclaw_skills", "stvlynn/qclaw-skills")


def norm(s):
    return re.sub(r"\s+", " ", s or "").strip().lower()


def curl(url, timeout=25):
    try:
        p = subprocess.run(
            ["curl", "-sSL", "--max-time", str(timeout), "--connect-timeout", "8", "-o", "-", url],
            capture_output=True, timeout=timeout + 10)
    except Exception:
        return None
    if p.returncode == 0 and len(p.stdout) > 2000:
        return p.stdout
    return None


def fetch_repo(source):
    urls = []
    for br in BRANCHES:
        urls.append(PROXY + "https://github.com/%s/archive/refs/heads/%s.tar.gz" % (source, br))
        urls.append("https://codeload.github.com/%s/tar.gz/refs/heads/%s" % (source, br))
    for u in urls:
        blob = curl(u)
        if blob:
            return blob
    return None


def search_registry(name):
    url = "https://skills.sh/api/search?q=" + urllib.parse.quote(name)
    delay = 1.0
    for _ in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (codex-restore)"})
            with urllib.request.urlopen(req, timeout=30) as r:
                data = json.load(r)
            cands = [c for c in data.get("skills", []) if c.get("name", "").lower() == name.lower()]
            cands.sort(key=lambda c: -c.get("installs", 0))
            out = []
            for c in cands[:6]:
                parts = c["id"].split("/")
                out.append({"source": c["source"],
                            "path": parts[2] if len(parts) > 2 else "",
                            "installs": c.get("installs", 0)})
            return out
        except Exception:
            time.sleep(delay)
            delay = min(delay * 2, 30)
    return []


def frontmatter(path):
    try:
        raw = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return "", ""
    m = re.match(r"(?s)^---\s*\r?\n(.*?)\r?\n---", raw)
    if not m:
        return "", ""
    name = desc = ""
    key = None
    buf = []

    def flush():
        nonlocal name, desc
        if key == "name" and buf:
            name = norm(buf[0])
        elif key == "description" and buf:
            desc = re.sub(r"\s+", " ", " ".join(buf)).strip().strip('"').strip("'")

    for line in m.group(1).splitlines():
        km = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if km:
            flush()
            key = km.group(1)
            buf = [km.group(2).strip().strip('"').strip("'")]
        elif key and line.strip():
            buf.append(line.strip())
    flush()
    return name, desc


def unpack(blob, tmp):
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp)
    with tarfile.open(fileobj=io.BytesIO(blob), mode="r:gz") as tf:
        tf.extractall(tmp)
    roots = [os.path.join(tmp, d) for d in os.listdir(tmp)]
    return roots[0] if roots else tmp


def skill_dirs(root):
    out = {}
    for dp, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "__pycache__", ".venv", "dist", "build")]
        if "SKILL.md" in files:
            rel = os.path.relpath(dp, root)
            parts = rel.split(os.sep)
            if parts[0].startswith("skills-"):
                parts = parts[1:]
            out[os.path.basename(dp)] = dp
            out["/".join(parts)] = dp
    return out


def install_skill(src, dst):
    """复制技能目录；跳过上游里指向仓库外的悬空软链接。"""
    os.makedirs(dst, exist_ok=True)
    for dp, dirs, files in os.walk(src):
        rel = os.path.relpath(dp, src)
        base = dst if rel == "." else os.path.join(dst, rel)
        os.makedirs(base, exist_ok=True)
        for fn in files + dirs:
            s = os.path.join(dp, fn)
            d = os.path.join(base, fn)
            if os.path.islink(s):
                if not os.path.exists(os.path.realpath(s)):
                    continue                      # 悬空软链接，跳过
                try:
                    os.symlink(os.readlink(s), d)
                except OSError:
                    pass
            elif os.path.isfile(s):
                shutil.copy2(s, d)


def install(src, name):
    target = os.path.join(CODEX_SKILLS, name)
    if os.path.exists(target):
        return "SKIP_EXISTS"
    install_skill(src, target)
    mirror = os.path.join(AGENTS_SKILLS, name)
    if not os.path.exists(mirror):
        install_skill(src, mirror)
    return "OK"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--index", default=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "skills.agents.json"))
    ap.add_argument("--refresh", action="store_true", help="先删掉已安装的第三方技能再装")
    ap.add_argument("--list", action="store_true", help="只打印解析结果")
    args = ap.parse_args()

    index = json.load(open(args.index, encoding="utf-8"))
    os.makedirs(CODEX_SKILLS, exist_ok=True)
    os.makedirs(AGENTS_SKILLS, exist_ok=True)

    if args.refresh:
        for x in index:
            p = os.path.join(CODEX_SKILLS, x["name"])
            if os.path.isdir(p):
                shutil.rmtree(p)

    sources = {}
    for x in index:
        cands = search_registry(x["name"])
        sources[x["name"]] = cands
        if not args.list:
            mark = "OK " if os.path.exists(os.path.join(CODEX_SKILLS, x["name"])) else "-- "
            top = ("%s@%s" % (cands[0]["source"], cands[0]["path"])) if cands else "未找到"
            print("%s%-28s %s" % (mark, x["name"], top), flush=True)
        time.sleep(0.8)
    if args.list:
        return

    by_repo = {}
    for x in index:
        cands = sources.get(x["name"]) or []
        if cands and not os.path.exists(os.path.join(CODEX_SKILLS, x["name"])):
            by_repo.setdefault(cands[0]["source"], []).append((x["name"], cands[0]["path"]))

    tmp = "/tmp/restore-skill-cache"
    results = {}
    for i, (repo, items) in enumerate(sorted(by_repo.items()), 1):
        blob = fetch_repo(repo)
        if not blob:
            for name, _ in items:
                results[name] = "FETCH_FAIL"
            print("[%d/%d] FETCH_FAIL %s" % (i, len(by_repo), repo), flush=True)
            continue
        work = os.path.join(tmp, repo.replace("/", "__"))
        root = unpack(blob, work)
        dirs = skill_dirs(root)
        for name, path in items:
            src = dirs.get(path) or dirs.get(name) or dirs.get("skills/" + name)
            if not src:
                results[name] = "NOT_FOUND_IN_REPO"
                continue
            try:
                results[name] = install(src, name)
            except Exception as e:
                results[name] = "FAIL %s" % e
        shutil.rmtree(work, ignore_errors=True)
        ok = sum(1 for v in results.values() if v == "OK")
        print("[%d/%d] %s (ok=%d)" % (i, len(by_repo), repo, ok), flush=True)

    missing = [x for x in index if x["name"] not in results and
               not os.path.exists(os.path.join(CODEX_SKILLS, x["name"]))]
    if missing:
        repos = list(EXTRA_REPOS)
        for x in missing:
            for c in sources.get(x["name"], []):
                repos.append(c["source"])
        repos = list(dict.fromkeys(repos))
        for i, repo in enumerate(repos, 1):
            blob = fetch_repo(repo)
            if not blob:
                continue
            work = os.path.join(tmp, repo.replace("/", "__"))
            root = unpack(blob, work)
            by_desc, by_name = {}, {}
            for dp, _d, fs in os.walk(root):
                if "SKILL.md" in fs:
                    n, d = frontmatter(os.path.join(dp, "SKILL.md"))
                    if d:
                        by_desc[norm(d)] = dp
                    if n:
                        by_name[n] = dp
            for x in missing:
                if x["name"] in results:
                    continue
                src = by_desc.get(norm(x.get("description", ""))) or by_name.get(norm(x["name"]))
                if src:
                    try:
                        results[x["name"]] = install(src, x["name"]) + " (%s)" % repo
                    except Exception as e:
                        results[x["name"]] = "FAIL %s" % e
            shutil.rmtree(work, ignore_errors=True)
            print("[fallback %d/%d] %s" % (i, len(repos), repo), flush=True)
            if all(x["name"] in results for x in missing):
                break

    print("\n== 结果 ==")
    for k, v in sorted(results.items()):
        print("  %s: %s" % (k, v))
    left = [x["name"] for x in index if not os.path.exists(os.path.join(CODEX_SKILLS, x["name"]))]
    print("\n仍缺失 (%d): %s" % (len(left), left))
    json.dump(results, open("/tmp/restore-skills-report.json", "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    sys.exit(main())
