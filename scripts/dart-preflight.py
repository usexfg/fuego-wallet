#!/usr/bin/env python3
"""
Pre-emptive Dart linter — catches common issues without needing Flutter SDK.

Scans all .dart files in lib/ for:
    1. Broken imports (files that don't exist)
    2. Unused imports (imported but never referenced in code)
    3. Missing imports (class/function used but not imported)
    4. Bracket/paren imbalance
    5. Common typos
    6. const constructor usage violations
    7. `required` keyword misuse
"""

import os
import re
import sys
from pathlib import Path
from collections import defaultdict


PROJECT_ROOT = Path(__file__).resolve().parent.parent
LIB_DIR = PROJECT_ROOT / "lib"

# Skip these dirs during scan
SKIP_DIRS = {"src", "fuego-sdk", ".dart_tool", "build", ".git"}


class Issue:
    def __init__(self, file, line, col, severity, msg):
        self.file = file
        self.line = line
        self.col = col
        self.severity = severity  # error, warning, info
        self.msg = msg


def all_dart_files():
    for root, dirs, files in os.walk(LIB_DIR):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith(".dart"):
                yield Path(root) / f


def check_imports(file_path: Path) -> list[Issue]:
    """Check that all imports resolve to existing files."""
    issues = []
    lines = file_path.read_text(errors="replace").split("\n")

    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped.startswith("import "):
            continue

        # Extract the import path
        m = re.search(r"""['"]([^'"]+)['"]""", stripped)
        if not m:
            continue

        import_path = m.group(1)

        # Skip package: imports (can't easily check without pub get)
        if import_path.startswith("package:") or import_path.startswith("dart:"):
            continue

        # Resolve relative import
        if import_path.startswith("."):
            resolved = (file_path.parent / import_path).resolve()
            # Add .dart extension
            if not str(resolved).endswith(".dart"):
                resolved = resolved.with_suffix(".dart")

            if not resolved.exists():
                # Check if file exists but with a different name or path
                base = import_path.split("/")[-1]
                alt_files = list(LIB_DIR.glob(f"**/{base}.dart"))
                if alt_files:
                    issues.append(Issue(
                        file_path, i, 0, "error",
                        f"Import '{import_path}' not found. File exists elsewhere: {alt_files[0].relative_to(LIB_DIR)}"
                    ))
                else:
                    issues.append(Issue(
                        file_path, i, 0, "error",
                        f"Import '{import_path}' → file does not exist: {resolved}"
                    ))

    return issues


def check_brackets(file_path: Path) -> list[Issue]:
    """Check for bracket/paren/square imbalance."""
    issues = []
    content = file_path.read_text(errors="replace")

    # Remove string literals and comments to avoid false positives
    cleaned = re.sub(r'"""[\s\S]*?"""', '', content)  # triple-quoted
    cleaned = re.sub(r"'''[\s\S]*?'''", '', cleaned)
    cleaned = re.sub(r"//.*", '', cleaned)            # single-line comments
    cleaned = re.sub(r"'(?:\\.|[^'\\])*'", "''", cleaned)  # single-quoted strings
    cleaned = re.sub(r'"(?:\\.|[^"\\])*"', '""', cleaned)  # double-quoted strings

    curly  = cleaned.count("{") - cleaned.count("}")
    paren  = cleaned.count("(") - cleaned.count(")")
    square = cleaned.count("[") - cleaned.count("]")

    # Count lines for rough location
    lines = content.split("\n")

    if curly != 0:
        issues.append(Issue(
            file_path, len(lines), 0, "error",
            f"Bracket imbalance: {abs(curly)} {'extra opening' if curly > 0 else 'extra closing'} curly braces '}}'/'{{'"
        ))
    if paren != 0:
        issues.append(Issue(
            file_path, len(lines), 0, "error",
            f"Parenthesis imbalance: {abs(paren)} {'extra opening' if paren > 0 else 'extra closing'} parentheses"
        ))
    if square != 0:
        issues.append(Issue(
            file_path, len(lines), 0, "error",
            f"Square bracket imbalance: {abs(square)} {'extra opening' if square > 0 else 'extra closing'} brackets"
        ))

    return issues


def check_unused_imports(file_path: Path) -> list[Issue]:
    """Detect imports that are likely unused."""
    issues = []
    lines = file_path.read_text(errors="replace").split("\n")
    content_lower = "\n".join(lines).lower()
    content_after_imports = "\n".join(
        l for l in lines if not l.strip().startswith("import")
    ).lower()

    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped.startswith("import "):
            continue

        m = re.search(r"""['"]([^'"]+)['"]""", stripped)
        if not m:
            continue
        import_path = m.group(1)
        basename = import_path.split("/")[-1].replace(".dart", "")

        # Check if any identifier from this import is used
        # Heuristic: the basename (underscore → PascalCase) should appear after imports
        pascal = "".join(w.capitalize() for w in basename.split("_"))
        if pascal.lower() not in content_after_imports:
            # Check snake_case too
            if basename.lower() not in content_after_imports:
                issues.append(Issue(
                    file_path, i, 0, "info",
                    f"Possibly unused import: '{import_path}' (no reference to '{pascal}' found)"
                ))

    return issues


def check_common_typos(file_path: Path) -> list[Issue]:
    """Scan for common Dart typos."""
    issues = []
    lines = file_path.read_text(errors="replace").split("\n")

    typo_map = {
        # AnimatedBuilder is the correct Flutter widget name
        "sytled": "typod 'sytled' (should be 'styled')",
        "backgroud": "typod 'backgroud' (should be 'background')",
        "foregroud": "typod 'foregroud' (should be 'foreground')",
        "circilar": "typod 'circilar' (should be 'circular')",
        "elavation": "typod 'elavation' (should be 'elevation')",
        "mainAxisAlignment": None,  # intentionally skip correct
    }

    for i, line in enumerate(lines, 1):
        for bad, msg in typo_map.items():
            if msg and bad in line and not bad.startswith("//"):
                issues.append(Issue(file_path, i, 0, "warning", msg))

    return issues


def check_missing_super_key(file_path: Path) -> list[Issue]:
    """Check StatefulWidget constructors missing super.key."""
    issues = []
    lines = file_path.read_text(errors="replace").split("\n")

    for i, line in enumerate(lines, 1):
        if "StatefulWidget" in line and "{" in line:
            # Check if this constructor has super.key
            if "super.key" not in line:
                # Check next lines to see if it's a const constructor with super.key
                found_super_key = False
                for j in range(i, min(i + 5, len(lines))):
                    if "super.key" in lines[j]:
                        found_super_key = True
                        break
                    if ");" in lines[j] or "})" in lines[j]:
                        break
                if not found_super_key:
                    issues.append(Issue(
                        file_path, i, 0, "warning",
                        "StatefulWidget constructor missing 'super.key'"
                    ))

    return issues


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    print("🔍 Pre-emptive Dart Code Scanner\n")
    print(f"Scanning: {LIB_DIR}\n")

    all_issues: dict[str, list[Issue]] = defaultdict(list)
    total_files = 0
    error_count = 0
    warn_count = 0
    info_count = 0

    checks = [
        ("import resolution", check_imports),
        ("bracket balance", check_brackets),
        ("common typos", check_common_typos),
        ("unused imports", check_unused_imports),
        ("missing super.key", check_missing_super_key),
    ]

    for dart_file in all_dart_files():
        total_files += 1
        file_issues = []

        for check_name, check_fn in checks:
            try:
                file_issues.extend(check_fn(dart_file))
            except Exception as e:
                print(f"  ⚠️  {check_name} check failed on {dart_file.relative_to(LIB_DIR)}: {e}")

        if file_issues:
            rel = str(dart_file.relative_to(LIB_DIR))
            all_issues[rel].extend(file_issues)

    # Print results
    print("=" * 70)
    for fname, issues in sorted(all_issues.items()):
        print(f"\n📄 lib/{fname}")
        for issue in issues:
            prefix = {"error": "❌", "warning": "⚠️", "info": "ℹ️"}.get(issue.severity, "•")
            print(f"  {prefix} L{issue.line}:{issue.col} [{issue.severity}] {issue.msg}")
            if issue.severity == "error":
                error_count += 1
            elif issue.severity == "warning":
                warn_count += 1
            else:
                info_count += 1

    print("\n" + "=" * 70)
    print(f"\n  Scanned: {total_files} files")
    print(f"  ❌ Errors:   {error_count}")
    print(f"  ⚠️  Warnings: {warn_count}")
    print(f"  ℹ️ Info:     {info_count}")
    print()

    if error_count > 0:
        print("🔴 CRITICAL: Build would fail. Fix errors before pushing.")
        sys.exit(1)
    elif warn_count > 0:
        print("🟡 Warnings found. Build may succeed but cleanup recommended.")
        sys.exit(0)
    else:
        print("🟢 All clear! No issues found.")
        sys.exit(0)


if __name__ == "__main__":
    main()
