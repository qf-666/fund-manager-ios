from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT_FILE = ROOT / "project.yml"
SOURCE_DIR = ROOT / "src"
EXPECTED_DEPLOYMENT_TARGET = "16.0"

DISALLOWED_PATTERNS = {
    ".topBarLeading": "iOS 17+ toolbar placement",
    ".topBarTrailing": "iOS 17+ toolbar placement",
    "ContentUnavailableView(": "iOS 17+ SwiftUI unavailable-content view",
    "connectionProxyDictionary": "CFNetwork proxy override can crash on iOS 16.x",
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def collect_project_errors(project_text: str) -> list[str]:
    errors: list[str] = []

    base_target = re.search(r"IPHONEOS_DEPLOYMENT_TARGET:\s*([0-9.]+)", project_text)
    app_target = re.search(r'deploymentTarget:\s*"([0-9.]+)"', project_text)

    if not base_target:
        errors.append("project.yml missing IPHONEOS_DEPLOYMENT_TARGET")
    elif base_target.group(1) != EXPECTED_DEPLOYMENT_TARGET:
        errors.append(
            f"project.yml IPHONEOS_DEPLOYMENT_TARGET is {base_target.group(1)}, expected {EXPECTED_DEPLOYMENT_TARGET}"
        )

    if not app_target:
        errors.append('project.yml missing target deploymentTarget')
    elif app_target.group(1) != EXPECTED_DEPLOYMENT_TARGET:
        errors.append(
            f'project.yml deploymentTarget is {app_target.group(1)}, expected {EXPECTED_DEPLOYMENT_TARGET}'
        )

    return errors


def collect_source_errors() -> list[str]:
    errors: list[str] = []

    for swift_file in sorted(SOURCE_DIR.rglob("*.swift")):
        content = read_text(swift_file)
        for line_number, line in enumerate(content.splitlines(), start=1):
            for pattern, reason in DISALLOWED_PATTERNS.items():
                if pattern in line:
                    relative = swift_file.relative_to(ROOT).as_posix()
                    errors.append(f"{relative}:{line_number} uses {pattern} ({reason})")

    return errors


def main() -> int:
    errors: list[str] = []
    errors.extend(collect_project_errors(read_text(PROJECT_FILE)))
    errors.extend(collect_source_errors())

    if errors:
        print("iOS 16 compatibility check failed:")
        for item in errors:
            print(f"- {item}")
        return 1

    print("iOS 16 compatibility check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
