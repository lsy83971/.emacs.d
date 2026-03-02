#!/usr/bin/env python3
"""
repo-map.py — Aider 风格的代码结构提取器

用法：
  python3 repo-map.py [目录或文件...]
  python3 repo-map.py src/
  python3 repo-map.py --tokens 2000 src/
  python3 repo-map.py --json src/          # 输出 JSON，供 Emacs 解析

支持语言：Python（AST精确解析）+ JS/TS/Go/Rust/Java/C（正则）
输出：紧凑的符号地图，可直接注入 gptel 上下文
"""

import ast
import os
import re
import sys
import json
import argparse
import hashlib
import pickle
from pathlib import Path
from collections import defaultdict
from typing import NamedTuple

# ─── 数据结构 ────────────────────────────────────────────────────────────────

class Symbol(NamedTuple):
    file: str       # 相对路径
    line: int
    kind: str       # def / class / method / var / import
    name: str
    signature: str  # 完整签名，如 "def foo(x: int) -> str"
    refs: list      # 被哪些文件引用（用于 PageRank）

# ─── 缓存（基于文件 mtime，仿 Aider 实现）────────────────────────────────────

CACHE_FILE = Path(".repo-map.cache")

def load_cache():
    if CACHE_FILE.exists():
        try:
            with open(CACHE_FILE, "rb") as f:
                return pickle.load(f)
        except Exception:
            pass
    return {}

def save_cache(cache):
    try:
        with open(CACHE_FILE, "wb") as f:
            pickle.dump(cache, f)
    except Exception:
        pass

# ─── Python 解析（AST 精确） ──────────────────────────────────────────────────

def parse_python(filepath: str, rel_path: str) -> list[Symbol]:
    try:
        with open(filepath, encoding="utf-8", errors="ignore") as f:
            source = f.read()
        tree = ast.parse(source, filename=filepath)
    except SyntaxError:
        return []

    symbols = []

    def annotation_str(node):
        if node is None:
            return ""
        try:
            return ast.unparse(node)
        except Exception:
            return "..."

    def args_str(args):
        parts = []
        # positional args
        n_defaults = len(args.defaults)
        n_args = len(args.args)
        for i, arg in enumerate(args.args):
            ann = f": {annotation_str(arg.annotation)}" if arg.annotation else ""
            default_idx = i - (n_args - n_defaults)
            if default_idx >= 0:
                default = f" = {ast.unparse(args.defaults[default_idx])}"
            else:
                default = ""
            parts.append(f"{arg.arg}{ann}{default}")
        if args.vararg:
            ann = f": {annotation_str(args.vararg.annotation)}" if args.vararg.annotation else ""
            parts.append(f"*{args.vararg.arg}{ann}")
        for arg in args.kwonlyargs:
            ann = f": {annotation_str(arg.annotation)}" if arg.annotation else ""
            parts.append(f"{arg.arg}{ann}")
        if args.kwarg:
            ann = f": {annotation_str(args.kwarg.annotation)}" if args.kwarg.annotation else ""
            parts.append(f"**{args.kwarg.arg}{ann}")
        return ", ".join(parts)

    class Visitor(ast.NodeVisitor):
        def __init__(self):
            self.class_stack = []

        def visit_ClassDef(self, node):
            bases = ", ".join(annotation_str(b) for b in node.bases)
            sig = f"class {node.name}({bases}):" if bases else f"class {node.name}:"
            symbols.append(Symbol(rel_path, node.lineno, "class", node.name, sig, []))
            self.class_stack.append(node.name)
            self.generic_visit(node)
            self.class_stack.pop()

        def visit_FunctionDef(self, node):
            args = args_str(node.args)
            ret = f" -> {annotation_str(node.returns)}" if node.returns else ""
            # decorators
            decs = "".join(f"@{ast.unparse(d)}\n" for d in node.decorator_list)
            prefix = "async def" if isinstance(node, ast.AsyncFunctionDef) else "def"
            sig = f"{decs}{prefix} {node.name}({args}){ret}:"
            kind = "method" if self.class_stack else "def"
            symbols.append(Symbol(rel_path, node.lineno, kind, node.name, sig, []))
            self.generic_visit(node)

        visit_AsyncFunctionDef = visit_FunctionDef

        def visit_Import(self, node):
            for alias in node.names:
                sig = f"import {alias.name}"
                if alias.asname:
                    sig += f" as {alias.asname}"
                symbols.append(Symbol(rel_path, node.lineno, "import", alias.asname or alias.name, sig, []))

        def visit_ImportFrom(self, node):
            module = node.module or ""
            names = ", ".join(
                (f"{a.name} as {a.asname}" if a.asname else a.name)
                for a in node.names
            )
            sig = f"from {module} import {names}"
            symbols.append(Symbol(rel_path, node.lineno, "import", module, sig, []))

        def visit_Assign(self, node):
            # 只记录模块级别的常量/变量（全大写或类型注解）
            if not self.class_stack:
                for target in node.targets:
                    if isinstance(target, ast.Name):
                        try:
                            val = ast.unparse(node.value)[:40]
                        except Exception:
                            val = "..."
                        symbols.append(Symbol(rel_path, node.lineno, "var",
                                              target.id, f"{target.id} = {val}", []))

        def visit_AnnAssign(self, node):
            if isinstance(node.target, ast.Name):
                ann = annotation_str(node.annotation)
                symbols.append(Symbol(rel_path, node.lineno, "var",
                                      node.target.id, f"{node.target.id}: {ann}", []))

    Visitor().visit(tree)
    return symbols

# ─── 多语言正则解析 ───────────────────────────────────────────────────────────

LANG_PATTERNS = {
    ".js":  [
        (r"^(?:export\s+)?(?:async\s+)?function\s+(\w+)\s*\(([^)]*)\)", "def"),
        (r"^(?:export\s+)?class\s+(\w+)(?:\s+extends\s+\w+)?", "class"),
        (r"^(?:export\s+)?(?:const|let)\s+(\w+)\s*=\s*(?:async\s+)?\(", "def"),
    ],
    ".ts":  [
        (r"^(?:export\s+)?(?:async\s+)?function\s+(\w+)\s*(?:<[^>]*>)?\(([^)]*)\)(?:\s*:\s*[^\{]+)?", "def"),
        (r"^(?:export\s+)?(?:abstract\s+)?class\s+(\w+)", "class"),
        (r"^(?:export\s+)?interface\s+(\w+)", "class"),
        (r"^(?:export\s+)?type\s+(\w+)\s*=", "var"),
    ],
    ".tsx": [  # same as ts
        (r"^(?:export\s+)?(?:async\s+)?function\s+(\w+)\s*(?:<[^>]*>)?\(([^)]*)\)(?:\s*:\s*[^\{]+)?", "def"),
        (r"^(?:export\s+)?(?:abstract\s+)?class\s+(\w+)", "class"),
        (r"^(?:export\s+)?interface\s+(\w+)", "class"),
    ],
    ".go": [
        (r"^func\s+(?:\(\w+\s+\*?\w+\)\s+)?(\w+)\s*\(([^)]*)\)(?:\s*[^\{]+)?", "def"),
        (r"^type\s+(\w+)\s+struct", "class"),
        (r"^type\s+(\w+)\s+interface", "class"),
    ],
    ".rs": [
        (r"^(?:pub\s+)?(?:async\s+)?fn\s+(\w+)\s*(?:<[^>]*>)?\(([^)]*)\)(?:\s*->[^\{]+)?", "def"),
        (r"^(?:pub\s+)?struct\s+(\w+)", "class"),
        (r"^(?:pub\s+)?enum\s+(\w+)", "class"),
        (r"^(?:pub\s+)?trait\s+(\w+)", "class"),
        (r"^(?:pub\s+)?impl(?:\s+\w+)?\s+for\s+(\w+)", "method"),
    ],
    ".java": [
        (r"(?:public|private|protected|static|\s)+\w+\s+(\w+)\s*\(([^)]*)\)\s*(?:throws\s+[\w,\s]+)?\s*\{", "def"),
        (r"(?:public|private|protected)?\s*(?:abstract|final)?\s*class\s+(\w+)", "class"),
        (r"(?:public|private|protected)?\s*interface\s+(\w+)", "class"),
    ],
    ".c": [
        (r"^(?:static\s+)?(?:inline\s+)?[\w\*]+\s+(\w+)\s*\(([^)]*)\)\s*\{", "def"),
        (r"^typedef\s+struct\s+\w*\s*\{", "class"),
    ],
    ".cpp": [
        (r"^(?:static\s+)?(?:inline\s+)?[\w\:\*&]+\s+(\w+)\s*\(([^)]*)\)(?:\s*(?:const|override|final))?\s*[\{\{;]", "def"),
        (r"^(?:class|struct)\s+(\w+)(?:\s*:\s*[\w\s,&*]+)?", "class"),
    ],
    ".el": [  # Emacs Lisp
        (r"^\(def(?:un|macro|subst|alias)\s+(\S+)", "def"),
        (r"^\(defvar\s+(\S+)", "var"),
        (r"^\(defcustom\s+(\S+)", "var"),
        (r"^\(defclass\s+(\S+)", "class"),
    ],
    ".rb": [
        (r"^(?:\s*)def\s+(?:self\.)?(\w+)\s*(?:\(([^)]*)\))?", "def"),
        (r"^class\s+(\w+)", "class"),
        (r"^module\s+(\w+)", "class"),
    ],
}

def parse_generic(filepath: str, rel_path: str, ext: str) -> list[Symbol]:
    patterns = LANG_PATTERNS.get(ext, [])
    if not patterns:
        return []
    symbols = []
    try:
        with open(filepath, encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except Exception:
        return []
    for lineno, line in enumerate(lines, 1):
        stripped = line.strip()
        for pattern, kind in patterns:
            m = re.match(pattern, stripped)
            if m:
                name = m.group(1)
                sig = stripped[:120].rstrip("{").rstrip()
                symbols.append(Symbol(rel_path, lineno, kind, name, sig, []))
                break
    return symbols

# ─── 引用分析（简化 PageRank 输入）──────────────────────────────────────────

def extract_references(filepath: str, all_names: set) -> set:
    """在文件中查找对其他符号的引用（用于计算重要性）"""
    try:
        with open(filepath, encoding="utf-8", errors="ignore") as f:
            content = f.read()
    except Exception:
        return set()
    # 提取所有标识符
    found = set(re.findall(r"\b([A-Za-z_]\w{2,})\b", content))
    return found & all_names

# ─── PageRank（简化版） ───────────────────────────────────────────────────────

def simple_pagerank(symbols: list[Symbol], refs_by_file: dict, iterations=10) -> dict:
    """
    给每个符号打分。
    核心思路：被越多文件引用的符号，分越高。
    返回 {name: score}
    """
    # 统计每个名字被引用次数
    ref_count = defaultdict(int)
    for refs in refs_by_file.values():
        for name in refs:
            ref_count[name] += 1

    scores = {}
    for sym in symbols:
        base = ref_count.get(sym.name, 0)
        # kind 加权：class > def > method > var > import
        weight = {"class": 3, "def": 2, "method": 2, "var": 1, "import": 0.5}.get(sym.kind, 1)
        scores[sym.name] = base * weight + weight * 0.1  # 保底分
    return scores

# ─── 主解析流程 ───────────────────────────────────────────────────────────────

IGNORE_DIRS = {".git", "__pycache__", "node_modules", ".venv", "venv",
               "env", "dist", "build", ".next", "target", ".cache",
               ".mypy_cache", ".pytest_cache", "coverage"}
IGNORE_EXTS = {".pyc", ".pyo", ".min.js", ".map", ".lock",
               ".png", ".jpg", ".gif", ".svg", ".ico",
               ".woff", ".ttf", ".eot"}
SUPPORTED_EXTS = {".py", ".js", ".ts", ".tsx", ".go", ".rs",
                  ".java", ".c", ".cpp", ".el", ".rb", ".jsx"}

def collect_files(paths: list[str]) -> list[tuple[str, str]]:
    """返回 [(绝对路径, 相对路径), ...]"""
    result = []
    root = os.getcwd()
    for p in paths:
        p = os.path.abspath(p)
        if os.path.isfile(p):
            ext = Path(p).suffix.lower()
            if ext in SUPPORTED_EXTS:
                rel = os.path.relpath(p, root)
                result.append((p, rel))
        elif os.path.isdir(p):
            for dirpath, dirnames, filenames in os.walk(p):
                dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS]
                for fname in filenames:
                    ext = Path(fname).suffix.lower()
                    if ext in SUPPORTED_EXTS and not any(fname.endswith(e) for e in IGNORE_EXTS):
                        abspath = os.path.join(dirpath, fname)
                        rel = os.path.relpath(abspath, root)
                        result.append((abspath, rel))
    return sorted(result)

def parse_file(abspath: str, rel_path: str, cache: dict) -> list[Symbol]:
    try:
        mtime = os.path.getmtime(abspath)
    except OSError:
        return []
    cache_key = abspath
    if cache_key in cache and cache[cache_key]["mtime"] == mtime:
        return cache[cache_key]["symbols"]

    ext = Path(abspath).suffix.lower()
    if ext == ".py":
        symbols = parse_python(abspath, rel_path)
    else:
        symbols = parse_generic(abspath, rel_path, ext)

    cache[cache_key] = {"mtime": mtime, "symbols": symbols}
    return symbols

# ─── 输出格式化 ───────────────────────────────────────────────────────────────

def estimate_tokens(text: str) -> int:
    """粗略估算 token 数（约 4 字符 = 1 token）"""
    return len(text) // 4

def format_map(symbols: list[Symbol], scores: dict, max_tokens: int,
               group_by_file: bool = True) -> str:
    """
    生成紧凑的 repo map 字符串。
    优先输出高分符号，按文件分组。
    """
    # 按文件分组
    by_file = defaultdict(list)
    for sym in symbols:
        by_file[sym.file].append(sym)

    # 给每个文件打分（文件内最高符号分）
    file_scores = {}
    for f, syms in by_file.items():
        file_scores[f] = max((scores.get(s.name, 0) for s in syms), default=0)

    # 按文件重要性排序
    sorted_files = sorted(by_file.keys(), key=lambda f: file_scores[f], reverse=True)

    lines = ["# Repo Map\n"]
    used_tokens = estimate_tokens(lines[0])

    for fpath in sorted_files:
        syms = by_file[fpath]
        # 文件内按分数排序，过滤掉 import（太多噪音）
        syms_filtered = [s for s in syms if s.kind != "import"]
        syms_sorted = sorted(syms_filtered, key=lambda s: scores.get(s.name, 0), reverse=True)

        if not syms_sorted:
            continue

        file_header = f"\n## {fpath}\n"
        file_content = ""
        for sym in syms_sorted:
            # 多行签名只取第一行
            first_line = sym.signature.split("\n")[0].strip()
            indent = "  " if sym.kind == "method" else ""
            file_content += f"{indent}{first_line}  # L{sym.line}\n"

        block = file_header + file_content
        block_tokens = estimate_tokens(block)

        if used_tokens + block_tokens > max_tokens:
            # 还有剩余空间，只输出部分
            remaining = max_tokens - used_tokens
            if remaining > 50:
                lines.append(file_header)
                for sym in syms_sorted:
                    first_line = sym.signature.split("\n")[0].strip()
                    indent = "  " if sym.kind == "method" else ""
                    entry = f"{indent}{first_line}  # L{sym.line}\n"
                    remaining -= estimate_tokens(entry)
                    if remaining < 0:
                        break
                    lines.append(entry)
            break
        else:
            lines.append(block)
            used_tokens += block_tokens

    total = estimate_tokens("".join(lines))
    lines.append(f"\n_[{len(symbols)} symbols, ~{total} tokens]_\n")
    return "".join(lines)

# ─── 入口 ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Aider 风格代码结构提取")
    parser.add_argument("paths", nargs="*", default=["."],
                        help="要分析的目录或文件（默认当前目录）")
    parser.add_argument("--tokens", type=int, default=2000,
                        help="输出 token 上限（默认 2000）")
    parser.add_argument("--json", action="store_true",
                        help="输出 JSON 格式（供 Emacs 解析）")
    parser.add_argument("--no-cache", action="store_true",
                        help="不使用缓存")
    parser.add_argument("--files-only", action="store_true",
                        help="只输出文件列表（不解析符号）")
    args = parser.parse_args()

    # 收集文件
    files = collect_files(args.paths)
    if not files:
        print("未找到支持的源文件", file=sys.stderr)
        sys.exit(1)

    if args.files_only:
        for _, rel in files:
            print(rel)
        return

    # 加载缓存
    cache = {} if args.no_cache else load_cache()

    # 解析所有文件
    all_symbols = []
    for abspath, rel in files:
        syms = parse_file(abspath, rel, cache)
        all_symbols.extend(syms)

    save_cache(cache)

    # 引用分析
    all_names = {s.name for s in all_symbols}
    refs_by_file = {}
    for abspath, rel in files:
        refs_by_file[rel] = extract_references(abspath, all_names)

    # 打分
    scores = simple_pagerank(all_symbols, refs_by_file)

    if args.json:
        # JSON 输出供 Emacs 解析
        output = {
            "files": [rel for _, rel in files],
            "symbols": [
                {
                    "file": s.file,
                    "line": s.line,
                    "kind": s.kind,
                    "name": s.name,
                    "signature": s.signature,
                    "score": round(scores.get(s.name, 0), 2),
                }
                for s in sorted(all_symbols, key=lambda x: scores.get(x.name, 0), reverse=True)
                if s.kind != "import"
            ],
        }
        print(json.dumps(output, ensure_ascii=False, indent=2))
    else:
        print(format_map(all_symbols, scores, args.tokens))

if __name__ == "__main__":
    main()
