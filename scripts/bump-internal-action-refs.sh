#!/usr/bin/env bash
# Bump muthur-command/builder action refs (@OLD -> @NEW) under actions/ and .github/.
# Used by release-drafter before tagging so in-repo pins match the upcoming release.
#
# Env:
#   NEW_VERSION (required)  e.g. 2026.06.0
#   OLD_VERSION (optional)  latest release tag without mc_ prefix; if empty, inferred from repo
#
# Output (GITHUB_OUTPUT when set):
#   changed=true|false

set -euo pipefail

NEW_VERSION="${NEW_VERSION:?NEW_VERSION is required}"
OLD_VERSION="${OLD_VERSION:-}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-}"

log() { echo "[bump-internal-action-refs] $*"; }

if [[ "${NEW_VERSION}" =~ ^mc_ ]]; then
  log "NEW_VERSION must not include mc_ prefix (got ${NEW_VERSION})"
  exit 1
fi

mapfile -t TARGET_FILES < <(
  grep -rl 'muthur-command/builder/actions/' actions .github 2>/dev/null \
    | grep -E '\.(ya?ml)$' || true
)

if [[ ${#TARGET_FILES[@]} -eq 0 ]]; then
  log "No workflow/action files reference muthur-command/builder/actions/"
  if [[ -n "${GITHUB_OUTPUT}" ]]; then
    echo "changed=false" >> "${GITHUB_OUTPUT}"
  fi
  exit 0
fi

if [[ -z "${OLD_VERSION}" ]]; then
  mapfile -t FOUND < <(
    grep -rhoE 'muthur-command/builder/actions/[^@]+@(mc_)?[0-9]{4}\.[0-9]{2}\.[0-9]+' \
      "${TARGET_FILES[@]}" 2>/dev/null \
      | sed -E 's/.*@(mc_)?//' \
      | sort -u
  )
  if [[ ${#FOUND[@]} -eq 1 ]]; then
    OLD_VERSION="${FOUND[0]}"
    log "Inferred OLD_VERSION=${OLD_VERSION} from repo"
  elif [[ ${#FOUND[@]} -gt 1 ]]; then
    log "Multiple pinned versions in repo: ${FOUND[*]}; set OLD_VERSION explicitly"
    exit 1
  else
    log "No existing @version pins; nothing to bump"
    if [[ -n "${GITHUB_OUTPUT}" ]]; then
      echo "changed=false" >> "${GITHUB_OUTPUT}"
    fi
    exit 0
  fi
fi

if [[ "${OLD_VERSION}" == "${NEW_VERSION}" ]]; then
  log "OLD_VERSION already equals NEW_VERSION (${NEW_VERSION}); skip"
  if [[ -n "${GITHUB_OUTPUT}" ]]; then
    echo "changed=false" >> "${GITHUB_OUTPUT}"
  fi
  exit 0
fi

# Already bumped to NEW (e.g. recommit before tag exists).
already_new=0
missing_old=0
for f in "${TARGET_FILES[@]}"; do
  if grep -q "muthur-command/builder/actions/[^@]*@${NEW_VERSION}" "$f"; then
    ((already_new++)) || true
  fi
  if ! grep -qE "muthur-command/builder/actions/[^@]*@(mc_)?${OLD_VERSION}([^0-9]|$)" "$f"; then
    ((missing_old++)) || true
  fi
done
if [[ ${already_new} -gt 0 && ${missing_old} -eq ${#TARGET_FILES[@]} ]]; then
  log "Refs already at @${NEW_VERSION}; skip"
  if [[ -n "${GITHUB_OUTPUT}" ]]; then
    echo "changed=false" >> "${GITHUB_OUTPUT}"
  fi
  exit 0
fi

changed=false
for f in "${TARGET_FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    continue
  fi
  tmp="$(mktemp)"
  sed -E \
    -e "s#(muthur-command/builder/actions/[^@\"']+)@${OLD_VERSION}([^0-9]|$)#\1@${NEW_VERSION}\2#g" \
    -e "s#(muthur-command/builder/actions/[^@\"']+)@mc_${OLD_VERSION}([^0-9]|$)#\1@${NEW_VERSION}\2#g" \
    "$f" > "$tmp"
  if ! cmp -s "$f" "$tmp"; then
    mv "$tmp" "$f"
    changed=true
    log "Updated $f (@${OLD_VERSION} -> @${NEW_VERSION})"
  else
    rm -f "$tmp"
  fi
done

if [[ -n "${GITHUB_OUTPUT}" ]]; then
  if [[ "${changed}" == true ]]; then
    echo "changed=true" >> "${GITHUB_OUTPUT}"
  else
    echo "changed=false" >> "${GITHUB_OUTPUT}"
  fi
fi

if [[ "${changed}" == true ]]; then
  log "Done: bumped @${OLD_VERSION} -> @${NEW_VERSION}"
else
  log "No file changes (pins may already match @${NEW_VERSION})"
fi
