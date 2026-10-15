#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 INPUT.csv NEW_OUTPUT_DIR [WORKERS] [additional generator arguments...]" >&2
  exit 2
fi

script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
input_csv="$1"
output_dir="$2"
shift 2
workers=1
if [[ $# -gt 0 && "$1" != --* ]]; then
  workers="$1"
  shift
fi
[[ -f "$input_csv" ]] || { echo "Input CSV not found: $input_csv" >&2; exit 2; }
[[ "$workers" =~ ^[1-9][0-9]*$ ]] || { echo "WORKERS must be a positive integer" >&2; exit 2; }
[[ ! -e "$output_dir" ]] || { echo "Refusing to overwrite existing output directory: $output_dir" >&2; exit 2; }
mkdir -p -- "$output_dir"
output_dir="$(cd -- "$output_dir" && pwd)"
input_csv="$(cd -- "$(dirname -- "$input_csv")" && pwd)/$(basename -- "$input_csv")"

export MPLBACKEND="${MPLBACKEND:-Agg}"
export PYTHONUNBUFFERED=1
export PYTHONPATH="$script_root${PYTHONPATH:+:$PYTHONPATH}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"

# Module resolution must use this checkout even when called from another project.
cd -- "$script_root"

command_args=(python -m fragments.magma.op.Magma4MassSpecGYm
  "$@"
  --csv "$input_csv"
  --workers "$workers"
  --annotated-output "$output_dir/annotations.json"
  --output "$output_dir/summary.csv")
printf '%q ' "${command_args[@]}" > "$output_dir/command.sh"
printf '\n' >> "$output_dir/command.sh"
python - "$input_csv" "$output_dir" "$workers" "$@" <<'PY'
import datetime
import importlib.metadata
import json
import platform
import sys
from pathlib import Path

input_csv, output_dir, workers, *extra = sys.argv[1:]
config = {
    "started_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "input_csv": input_csv,
    "workers": int(workers),
    "extra_arguments": extra,
    "python": platform.python_version(),
    "packages": {name: importlib.metadata.version(name) for name in
                 ["numpy", "pandas", "numba", "rdkit", "tqdm", "matplotlib"]},
    "resume_supported": False,
}
Path(output_dir, "run_config.json").write_text(json.dumps(config, indent=2) + "\n")
PY

set +e
"${command_args[@]}" 2>&1 | tee "$output_dir/run.log"
pipeline_status=("${PIPESTATUS[@]}")
generator_status=${pipeline_status[0]}
if [[ "$generator_status" -eq 0 && "${pipeline_status[1]}" -ne 0 ]]; then
  generator_status=${pipeline_status[1]}
fi
set -e
printf '%s\n' "$generator_status" > "$output_dir/exit_code.txt"
exit "$generator_status"
