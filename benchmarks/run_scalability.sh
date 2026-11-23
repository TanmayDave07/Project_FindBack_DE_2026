#!/usr/bin/env bash
# Reproduce the final CP4 configuration and all 90 timed executions.
# Run from the repository root with the faculty CSVs in large_data/.
# Usage: bash benchmarks/run_scalability.sh <NEW_database_name> [result_folder]
# Existing databases are never dropped. Use a different result folder to
# preserve the committed measurements when running on another computer.
set -euo pipefail
DB="${1:?a NEW database name is required}"
PHASE="${2:-large_reproduction}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="benchmarks/results/$PHASE/evidence"
mkdir -p "$OUT"
createdb "$DB"
psql -X -v ON_ERROR_STOP=1 -d "$DB" \
    -f sql/01_schema.sql -f sql/07_load_large_data.sql -f sql/05_indexes.sql
psql -X -v ON_ERROR_STOP=1 -d "$DB" -c 'VACUUM (ANALYZE);'
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f sql/08_partitioning.sql \
    > "$OUT/partitioning.txt" 2>&1
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f sql/09_scalability_tuning.sql
psql -X -v ON_ERROR_STOP=1 -d "$DB" -f benchmarks/validate_scalability.sql \
    > "$OUT/validation.txt" 2>&1
python3 benchmarks/collect_metadata.py "$DB" "$OUT/before_benchmark_metadata.json"
bash benchmarks/run_benchmark.sh "$DB" "$PHASE" 3 sql/06_optimized_queries.sql
python3 benchmarks/collect_metadata.py "$DB" "$OUT/after_benchmark_metadata.json"
python3 - "$OUT" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
before = json.loads((path / 'before_benchmark_metadata.json').read_text())
after = json.loads((path / 'after_benchmark_metadata.json').read_text())
if before['tables'] != after['tables']:
    raise SystemExit('FAIL: benchmark changed table counts or checksums')
print('PASS: all table counts and checksums unchanged after write rollbacks')
PY
