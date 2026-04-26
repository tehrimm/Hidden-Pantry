from __future__ import annotations

from pathlib import Path
import fnmatch


LCOV_PATH = Path("coverage/lcov.info")
UNIT_SCOPE_PATH = Path("coverage/unit_scope.lcov.info")

# UI-heavy or generated files that are better covered by widget/integration tests,
# not pure unit tests.
UNIT_SCOPE_EXCLUDES = [
    "lib/**/screens/**",
    "lib/**/widgets/**",
    "lib/**/upload/**",
    "lib/firebase_options.dart",
    "lib/main.dart",
    "lib/screens/**",
]


def parse_record(record: str) -> tuple[str | None, int, int]:
    sf = None
    lh = 0
    lf = 0
    for line in record.splitlines():
        if line.startswith("SF:"):
            sf = line[3:].replace("\\", "/")
        elif line.startswith("LH:"):
            lh += int(line[3:])
        elif line.startswith("LF:"):
            lf += int(line[3:])
    return sf, lh, lf


def in_unit_scope(path: str) -> bool:
    return not any(fnmatch.fnmatch(path, pattern) for pattern in UNIT_SCOPE_EXCLUDES)


def pct(lh: int, lf: int) -> float:
    return (lh / lf * 100.0) if lf else 0.0


def main() -> None:
    if not LCOV_PATH.exists():
        raise SystemExit(f"Missing coverage file: {LCOV_PATH}")

    records = LCOV_PATH.read_text(encoding="utf-8", errors="ignore").split("end_of_record\n")

    raw_lh = raw_lf = 0
    unit_lh = unit_lf = 0
    kept_records: list[str] = []

    for record in records:
        sf, lh, lf = parse_record(record)
        if not sf:
            continue

        raw_lh += lh
        raw_lf += lf

        if in_unit_scope(sf):
            unit_lh += lh
            unit_lf += lf
            kept_records.append(record.strip() + "\nend_of_record\n")

    UNIT_SCOPE_PATH.write_text("".join(kept_records), encoding="utf-8")

    print(f"Raw coverage:        {pct(raw_lh, raw_lf):.2f}% (LH={raw_lh}, LF={raw_lf})")
    print(f"Unit-scope coverage: {pct(unit_lh, unit_lf):.2f}% (LH={unit_lh}, LF={unit_lf})")
    print(f"Saved filtered report: {UNIT_SCOPE_PATH}")


if __name__ == "__main__":
    main()
