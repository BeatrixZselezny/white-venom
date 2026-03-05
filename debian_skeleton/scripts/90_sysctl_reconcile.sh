#!/usr/bin/env bash
# 90_sysctl_reconcile.sh — White Venom helper
#
# Purpose:
#   - Report sysctl key collisions (same key set in multiple sysctl.d files)
#   - Optionally generate a final-authority file (e.g., /etc/sysctl.d/99_whitevenom_final.conf)
#     that re-asserts White Venom desired values last, to remove ambiguity.
#
# Notes:
#   - This script does NOT require systemd. It works on sysctl --system semantics.
#   - It does NOT edit vendor files; it only writes an optional final file you control.
#
# Usage:
#   sudo ./90_sysctl_reconcile.sh --report
#   sudo ./90_sysctl_reconcile.sh --emit-final
#   sudo ./90_sysctl_reconcile.sh --emit-final --apply-final
#
# Options:
#   --report                 Print collision report (default)
#   --emit-final             Write final-authority file (default path below)
#   --apply-final             After emitting, apply with: sysctl -p <file>
#   --out <path>             Output file path (default: /etc/sysctl.d/99_whitevenom_final.conf)
#   --scope whitevenom|all   Which keys to emit in final file (default: whitevenom)
#                            - whitevenom: keys found in WV sysctl files under /etc/sysctl.d
#                            - all: emit all keys seen in merged sysctl config set (not recommended)
#   --help

set -euo pipefail

OUT="/etc/sysctl.d/99_whitevenom_final.conf"
MODE="report"
APPLY_FINAL=0
SCOPE="whitevenom"

usage() {
  sed -n '1,80p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report) MODE="report"; shift ;;
    --emit-final) MODE="emit"; shift ;;
    --apply-final) APPLY_FINAL=1; shift ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --scope) SCOPE="${2:-}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

# sysctl.d precedence (higher priority first).
# We then merge by basename (higher priority wins) and sort by basename.
DIRS=(
  "/etc/sysctl.d"
  "/run/sysctl.d"
  "/usr/local/lib/sysctl.d"
  "/usr/lib/sysctl.d"
  "/lib/sysctl.d"
)

trim() { sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//'; }

# Build selected config file list:
#   - merge files by basename across DIRS, priority = first DIR in list
#   - then sort basenames
declare -A selected_by_base
declare -A prio_by_base

for i in "${!DIRS[@]}"; do
  d="${DIRS[$i]}"
  [[ -d "$d" ]] || continue
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    if [[ -z "${selected_by_base[$base]+x}" ]]; then
      selected_by_base["$base"]="$f"
      prio_by_base["$base"]="$i"
    fi
  done < <(find "$d" -maxdepth 1 -type f -name "*.conf" -print0 2>/dev/null)
done

# Create sorted apply list by basename.
mapfile -t bases < <(printf '%s\n' "${!selected_by_base[@]}" | sort)
APPLY_FILES=()
for b in "${bases[@]}"; do
  APPLY_FILES+=("${selected_by_base[$b]}")
done
# sysctl.conf is applied after sysctl.d set (common practice); include if present.
[[ -f "/etc/sysctl.conf" ]] && APPLY_FILES+=("/etc/sysctl.conf")

# Parse "key=value" and "key value"
declare -A final_value
declare -A final_src
declare -A seen_count
declare -A all_values   # key -> newline separated "file:line => value"

parse_file() {
  local f="$1"
  local lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno+1))
    # Strip comments (anything after #). Sysctl configs rarely need literal '#'.
    line="${line%%#*}"
    line="$(printf '%s' "$line" | trim)"
    [[ -z "$line" ]] && continue

    local key="" val=""
    if [[ "$line" =~ ^([A-Za-z0-9_.-]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
    elif [[ "$line" =~ ^([A-Za-z0-9_.-]+)[[:space:]]+(.+)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
    else
      continue
    fi
    val="$(printf '%s' "$val" | trim)"

    seen_count["$key"]=$(( ${seen_count["$key"]:-0} + 1 ))
    all_values["$key"]+="$f:$lineno => $val"$'\n'

    final_value["$key"]="$val"
    final_src["$key"]="$f:$lineno"
  done < "$f"
}

for f in "${APPLY_FILES[@]}"; do
  [[ -r "$f" ]] || continue
  parse_file "$f"
done

# Collision report
report_collisions() {
  local any=0
  echo "== sysctl collision report (merged sysctl.d set) =="
  echo "Applied config set (basename-merged, sorted):"
  for f in "${APPLY_FILES[@]}"; do
    [[ -r "$f" ]] && echo "  - $f"
  done
  echo

  for k in $(printf '%s\n' "${!seen_count[@]}" | sort); do
    [[ "${seen_count[$k]}" -ge 2 ]] || continue
    # Determine if values differ
    # Collect unique values
    mapfile -t vals < <(printf '%s' "${all_values[$k]}" | awk -F'=> ' 'NF==2{print $2}' | sort -u)
    if [[ "${#vals[@]}" -ge 2 ]]; then
      any=1
      echo "[CONFLICT] $k"
      printf '%s' "${all_values[$k]}" | sed 's/^/  /'
      echo "  FINAL: ${final_src[$k]} => ${final_value[$k]}"
      echo
    fi
  done

  if [[ "$any" -eq 0 ]]; then
    echo "No conflicting keys (same key with different values) found."
  else
    echo "Conflicts found. Consider emitting a final-authority file to remove ambiguity:"
    echo "  sudo $0 --emit-final --apply-final"
  fi
}

# Determine WV desired keys (from /etc/sysctl.d WV files)
collect_wv_files() {
  local -a wv=()
  # Conservative patterns: keep it aligned with your existing naming.
  # Add more patterns here if needed.
  while IFS= read -r -d '' f; do wv+=("$f"); done < <(find /etc/sysctl.d -maxdepth 1 -type f -name "*whitevenom*.conf" -print0 2>/dev/null || true)
  while IFS= read -r -d '' f; do wv+=("$f"); done < <(find /etc/sysctl.d -maxdepth 1 -type f -name "*venom*.conf" -print0 2>/dev/null || true)
  [[ -f "/etc/sysctl.d/99-security-ipv6.conf" ]] && wv+=("/etc/sysctl.d/99-security-ipv6.conf")

  # Deduplicate and sort
  printf '%s\n' "${wv[@]}" | awk 'NF' | sort -u
}

emit_final() {
  if [[ "$SCOPE" != "whitevenom" && "$SCOPE" != "all" ]]; then
    echo "Invalid --scope: $SCOPE (use whitevenom|all)" >&2
    exit 3
  fi

  declare -A desired
  declare -A desired_src

  if [[ "$SCOPE" == "whitevenom" ]]; then
    mapfile -t wv_files < <(collect_wv_files)
    if [[ "${#wv_files[@]}" -eq 0 ]]; then
      echo "No White Venom sysctl files found under /etc/sysctl.d (patterns: *whitevenom*, *venom*, 99-security-ipv6.conf)." >&2
      exit 4
    fi
    # Parse in lexical order; last assignment wins.
    for wf in "${wv_files[@]}"; do
      local lineno=0
      while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno+1))
        line="${line%%#*}"
        line="$(printf '%s' "$line" | trim)"
        [[ -z "$line" ]] && continue
        local key="" val=""
        if [[ "$line" =~ ^([A-Za-z0-9_.-]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
          key="${BASH_REMATCH[1]}"
          val="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ ^([A-Za-z0-9_.-]+)[[:space:]]+(.+)$ ]]; then
          key="${BASH_REMATCH[1]}"
          val="${BASH_REMATCH[2]}"
        else
          continue
        fi
        val="$(printf '%s' "$val" | trim)"
        desired["$key"]="$val"
        desired_src["$key"]="$wf:$lineno"
      done < "$wf"
    done
  else
    # all keys from merged set
    for k in "${!final_value[@]}"; do
      desired["$k"]="${final_value[$k]}"
      desired_src["$k"]="${final_src[$k]}"
    done
  fi

  local ts; ts="$(date -Is)"
  local tmp; tmp="$(mktemp)"
  {
    echo "# /etc/sysctl.d/99_whitevenom_final.conf"
    echo "# Generated by 90_sysctl_reconcile.sh on $ts"
    echo "# Scope: $SCOPE"
    echo "#"
    if [[ "$SCOPE" == "whitevenom" ]]; then
      echo "# This file re-asserts White Venom sysctl values LAST to remove ambiguity."
      echo "# Sources (WV files):"
      collect_wv_files | sed 's/^/#   - /'
      echo "#"
    else
      echo "# This file mirrors the final merged values of the whole sysctl config set."
      echo "# Not recommended unless you really want to freeze everything."
      echo "#"
    fi
    echo
    for k in $(printf '%s\n' "${!desired[@]}" | sort); do
      printf '%s = %s\n' "$k" "${desired[$k]}"
    done
    echo
  } > "$tmp"

  # Write atomically
  local outdir; outdir="$(dirname "$OUT")"
  if [[ ! -d "$outdir" ]]; then
    echo "Output directory does not exist: $outdir" >&2
    exit 5
  fi

  # Backup old if exists
  if [[ -f "$OUT" ]]; then
    cp -a "$OUT" "${OUT}.bak.$(date +%Y%m%d-%H%M%S)"
  fi
  install -m 0644 "$tmp" "$OUT"
  rm -f "$tmp"

  echo "Wrote final-authority sysctl file: $OUT"
  echo "Lines: $(wc -l < "$OUT" | tr -d ' ')"

  if [[ "$APPLY_FINAL" -eq 1 ]]; then
    echo "Applying: sysctl -p $OUT"
    sysctl -p "$OUT"
  else
    echo "Not applied. To apply immediately:"
    echo "  sudo sysctl -p $OUT"
    echo "Or on next sysctl --system run, it will be picked up automatically."
  fi
}

case "$MODE" in
  report) report_collisions ;;
  emit) emit_final ;;
  *) echo "Invalid mode: $MODE" >&2; exit 2 ;;
esac
