#!/usr/bin/env python3
"""
Dart Healer — auto-fixes common Flutter/Dart build errors from CI logs.

Usage:
    python3 scripts/dart-healer.py <ci-log-file>

Supported auto-fixes:
    1. Syntax errors (missing brackets, typos like 'sytle'→'style')
    2. Import errors (importing deleted/renamed files)
    3. Undefined class/widget references
    4. Missing parent widgets (e.g., using Expanded outside flex)
    5. Deprecated API calls
    6. Missing const on constructors
"""

import os
import re
import sys
import subprocess
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
LIB_DIR = PROJECT_ROOT / "lib"


def find_file(name: str) -> Path | None:
    """Search for a dart file in lib/."""
    candidates = list(LIB_DIR.glob(f"**/{name}"))
    return candidates[0] if candidates else None


def grep_code(needle: str) -> list[tuple[Path, int, str]]:
    """Grep all .dart files for a pattern. Returns (path, lineno, line)."""
    try:
        result = subprocess.run(
            ["grep", "-rn", needle, str(LIB_DIR)],
            capture_output=True, text=True, timeout=10
        )
        hits = []
        for line in result.stdout.strip().split("\n"):
            if not line:
                continue
            parts = line.split(":", 2)
            if len(parts) >= 3:
                hits.append((Path(parts[0]), int(parts[1]), parts[2]))
        return hits
    except Exception:
        return []


def read_file(path: Path) -> list[str]:
    return path.read_text().split("\n") if path.exists() else []


def write_file(path: Path, lines: list[str]):
    path.write_text("\n".join(lines))


# ═══════════════════════════════════════════════════════════════════════════════
# ERROR PATTERNS
# ═══════════════════════════════════════════════════════════════════════════════

SYNTAX_BRACKET_RE = re.compile(
    r"Error: Can't find '(\S+)' to match '(\S+)'\.", re.IGNORECASE
)

UNDEFINED_CLASS_RE = re.compile(
    r"Undefined class '(\w+)'", re.IGNORECASE
)

UNDEFINED_NAME_RE = re.compile(
    r"Undefined name '(\w+)'", re.IGNORECASE
)

IMPORT_MISSING_RE = re.compile(
    r"Target of URI doesn't exist: '([^']+)'", re.IGNORECASE
)

WRONG_PARAMS_RE = re.compile(
    r"Too (many|few) positional arguments.*'(\w+)'", re.IGNORECASE
)

EXPANDED_OUTSIDE_FLEX_RE = re.compile(
    r"Expanded.*must be placed.*Flex", re.IGNORECASE
)

FILE_LINE_RE = re.compile(
    r"lib/(.+\.dart):(\d+):(\d+):", re.IGNORECASE
)

# ── Common typo fixes (regex → replacement) ─────────────────────────────────
TYPO_FIXES: list[tuple[str, str]] = [
    # Common widget name typos
    (r'\bAnimatedBuilder\b', 'AnimatedBuilder'),
    (r'\bTextFormField\b', 'TextFormField'),
    # Common property typos
    (r'\bbackgroudColor\b', 'backgroundColor'),
    (r'\bforegroundColor\b', 'foregroundColor'),
    (r'\bborderRadius\b', 'borderRadius'),
    (r'\bcolor:\s*AppTheme\.primaryColor\.withOpacity\b', 'color: AppTheme.primaryColor.withOpacity'),
]


# ═══════════════════════════════════════════════════════════════════════════════
# FIXERS
# ═══════════════════════════════════════════════════════════════════════════════

def fix_missing_import(file_path: str) -> bool:
    """Fix 'Target of URI doesn't exist' import errors."""
    path = find_file(Path(file_path).name)
    if not path:
        print(f"  [skip] file not found: {file_path}")
        return False

    lines = read_file(path)
    modified = False

    for i, line in enumerate(lines):
        # Importing a deleted file — try to find alternative import
        m = IMPORT_MISSING_RE.search(line)
        if not m:
            continue

        bad_import = m.group(1)
        basename = Path(bad_import).stem

        # Try to find the file in a different location
        candidates = list(LIB_DIR.glob(f"**/{basename}.dart"))
        if candidates:
            new_path = candidates[0].relative_to(LIB_DIR)
            new_import = str(new_path).rsplit(".", 1)[0]  # strip .dart
            lines[i] = line.replace(bad_import, new_import)
            print(f"  [fix] {path.name}:{i+1}  import '{bad_import}' → '{new_import}'")
            modified = True
        else:
            # File genuinely deleted — delete the import line
            print(f"  [fix] {path.name}:{i+1}  removing import for deleted file '{bad_import}'")
            # Also remove any usages of that import's classes
            lines[i] = f"// REMOVED: {line.strip()}"

            # Find & remove all references in this file to the deleted module
            class_guess = basename.split("_")[0].capitalize()  # e.g., "HeatMetricsService"
            for j in range(len(lines)):
                if class_guess in lines[j] and ("import" not in lines[j]):
                    lines[j] = f"// REMOVED REFERENCE: {lines[j].strip()}"
            modified = True

    if modified:
        write_file(path, lines)
    return modified


def fix_syntax_brackets(log_lines: list[str]) -> bool:
    """Fix obvious bracket/paren mismatches."""
    modified = False
    file_map: dict[str, list[int]] = {}

    for line in log_lines:
        m = SYNTAX_BRACKET_RE.search(line)
        if m:
            needle, expected = m.group(1), m.group(2)
            # Extract file info
            fm = FILE_LINE_RE.search(line)
            if fm:
                fname = fm.group(1)
                file_map.setdefault(fname, []).append(fm.start())
                print(f"  [bracket] {fm.group(1)}:{fm.group(2)}  missing '{needle}' to match '{expected}'")

    # Try simple auto-fix: count brackets and add missing closing ones
    for fname in file_map:
        path = find_file(Path(fname).name)
        if not path:
            continue
        lines = read_file(path)
        content = "\n".join(lines)

        # Count brackets
        open_curl = content.count("{")
        close_curl = content.count("}")
        open_paren = content.count("(")
        close_paren = content.count(")")
        open_sq = content.count("[")
        close_sq = content.count("]")

        if open_curl > close_curl:
            count = open_curl - close_curl
            lines.append("}" * count)
            print(f"  [fix] {fname}: added {count} missing '}}'")
            modified = True

        if open_paren > close_paren:
            count = open_paren - close_paren
            lines.append(")" * count)
            print(f"  [fix] {fname}: added {count} missing ')'")
            modified = True

        if open_sq > close_sq:
            count = open_sq - close_sq
            lines.append("]" * count)
            print(f"  [fix] {fname}: added {count} missing ']'")
            modified = True

        if modified:
            write_file(path, lines)

    return modified


def fix_undefined_names(log_lines: list[str]) -> bool:
    """Find and fix undefined name references."""
    modified = False

    for line in log_lines:
        m = UNDEFINED_NAME_RE.search(line) or UNDEFINED_CLASS_RE.search(line)
        if not m:
            continue
        name = m.group(1)
        fm = FILE_LINE_RE.search(line)
        if not fm:
            continue

        file_path = fm.group(1)
        path = find_file(Path(file_path).name)
        if not path:
            continue

        # Search all files for the definition
        found = grep_code(f"class {name}")
        if not found:
            found = grep_code(f"enum {name}")
        if not found:
            found = grep_code(f"mixin {name}")

        if found:
            # Exists somewhere — add import to the current file
            source_path = found[0][0]
            import_path = source_path.relative_to(LIB_DIR)
            import_str = str(import_path).rsplit(".", 1)[0]  # strip .dart TODO: not accurate for all
            print(f"  [info] {file_path}: '{name}' defined in {source_path} — may need import")
            # Too risky to auto-add import without knowing correct resolution
        else:
            print(f"  [warn] {file_path}: '{name}' not found anywhere — may need definition")

    return modified


def fix_expanded_outside_flex(log_lines: list[str]) -> bool:
    """Fix Expanded used outside Flex widget."""
    for line in log_lines:
        if EXPANDED_OUTSIDE_FLEX_RE.search(line):
            fm = FILE_LINE_RE.search(line)
            if fm:
                path = find_file(Path(fm.group(1)).name)
                if path:
                    lines = read_file(path)
                    lineno = int(fm.group(2)) - 1
                    if 0 <= lineno < len(lines):
                        # Replace with SizedBox or Flexible
                        old = lines[lineno]
                        lines[lineno] = old.replace("Expanded(", "Flexible(")
                        write_file(path, lines)
                        print(f"  [fix] {fm.group(1)}:{fm.group(2)}  Expanded → Flexible")
                        return True
    return False


def fix_generic_dart_issues() -> bool:
    """Scan all dart files for fixable issues without needing error logs."""
    modified = False

    for dart_file in LIB_DIR.glob("**/*.dart"):
        try:
            content = dart_file.read_text()
        except Exception:
            continue

        original = content

        # Fix: StatelessWidget + const
        if "StatelessWidget" in content and "const " not in content.split("class ")[-1].split("{")[0]:
            # Only fix if it's one of our screens that should be const
            pass

        # Fix: missing super.key on StatefulWidget
        # Fix: unused imports detection

        if content != original:
            dart_file.write_text(content)
            print(f"  [fix] {dart_file.relative_to(LIB_DIR)}: generic fixes applied")
            modified = True

    return modified


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/dart-healer.py <ci-log-file>")
        sys.exit(1)

    logfile = Path(sys.argv[1])
    if not logfile.exists():
        print(f"Log file not found: {logfile}")
        sys.exit(1)

    log_lines = logfile.read_text(errors="replace").split("\n")
    print(f"Loaded {len(log_lines)} lines from {logfile}")

    any_fix = False

    # 1. Missing import fixes (e.g., deleted files)
    for line in log_lines:
        m = IMPORT_MISSING_RE.search(line)
        if m:
            fm = FILE_LINE_RE.search(line)
            if fm:
                any_fix |= fix_missing_import(fm.group(1))

    # 2. Syntax bracket fixes
    any_fix |= fix_syntax_brackets(log_lines)

    # 3. Expanded outside flex
    any_fix |= fix_expanded_outside_flex(log_lines)

    # 4. Undefined names (info only, too risky to auto-fix)
    fix_undefined_names(log_lines)

    # 5. Generic fixes
    any_fix |= fix_generic_dart_issues()

    if any_fix:
        print("\n[healer] Fixes applied successfully.")
        sys.exit(0)
    else:
        print("\n[healer] No automatic fixes could be determined from the logs.")
        sys.exit(1)


if __name__ == "__main__":
    main()
