#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
helper="$repo_root/bin/theme-drift"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
export XDG_STATE_HOME="$test_root/state"
export XDG_RUNTIME_DIR="$test_root/run"
export OMARCHY_PATH="$test_root/omarchy"
mock_bin="$test_root/bin"
log_file="$test_root/omarchy.log"
mkdir -p "$HOME/.config/omarchy/themes" "$XDG_STATE_HOME/theme-drift" "$XDG_RUNTIME_DIR" "$OMARCHY_PATH/themes/alpha" "$mock_bin"

cat >"$mock_bin/omarchy" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
  "theme current") printf 'Alpha\n' ;;
  "theme list")
    find "$OMARCHY_PATH/themes" "$HOME/.config/omarchy/themes" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -u
    ;;
  "theme set") printf 'set:%s\n' "$3" >>"$THEME_DRIFT_TEST_LOG" ;;
  "theme install")
    repo=${3%/}; repo=${repo%.git}; name=${repo##*/}
    slug=$(sed -E 's/^omarchy-//; s/-theme$//' <<<"$name" | tr '[:upper:]' '[:lower:]')
    printf 'install:%s\n' "$3" >>"$THEME_DRIFT_TEST_LOG"
    mkdir -p "$HOME/.config/omarchy/themes/$slug"
    printf 'set:%s\n' "$slug" >>"$THEME_DRIFT_TEST_LOG"
    ;;
  *) printf 'Unexpected omarchy call: %s\n' "$*" >&2; exit 2 ;;
esac
MOCK
chmod +x "$mock_bin/omarchy"
export PATH="$mock_bin:$PATH"
export THEME_DRIFT_TEST_LOG="$log_file"

cat >"$XDG_STATE_HOME/theme-drift/catalog.tsv" <<'CATALOG'
https://github.com/example/omarchy-alpha-theme.git	https://example.test/alpha.png	Alpha
https://github.com/example/omarchy-beta-theme.git	https://example.test/beta.png	Beta
CATALOG

"$helper" list >/dev/null
config="$XDG_STATE_HOME/theme-drift/config.json"
[[ -f $config && ! -L $config ]]
[[ $(stat -c %a "$config") == 600 ]]
[[ -d $XDG_RUNTIME_DIR/theme-drift && ! -L $XDG_RUNTIME_DIR/theme-drift ]]
[[ $(stat -c %a "$XDG_RUNTIME_DIR/theme-drift") == 700 ]]
jq '.lastBootId=""' "$config" >"$config.tmp"
mv "$config.tmp" "$config"

: >"$log_file"
"$helper" rotate-boot >/dev/null
if grep -q '^install:' "$log_file"; then
  printf 'FAIL: boot rotation attempted an unattended install\n' >&2
  exit 1
fi

if "$helper" apply beta >/dev/null 2>&1; then
  printf 'FAIL: uninstalled theme was accepted without repository approval\n' >&2
  exit 1
fi

if "$helper" apply beta https://attacker.example/omarchy-beta-theme.git >/dev/null 2>&1; then
  printf 'FAIL: non-GitHub repository was accepted\n' >&2
  exit 1
fi

if "$helper" apply beta https://github.com/example/omarchy-gamma-theme.git >/dev/null 2>&1; then
  printf 'FAIL: mismatched theme repository was accepted\n' >&2
  exit 1
fi

suggestion=$("$helper" suggest)
[[ $(jq -r '.slug' <<<"$suggestion") == beta ]]
[[ $(jq -r '.repo' <<<"$suggestion") == https://github.com/example/omarchy-beta-theme.git ]]
[[ -z $("$helper" suggest) ]]

jq '.lastSuggestionBootId=null | .rotationEnabled=false' "$config" >"$config.tmp"
mv "$config.tmp" "$config"
[[ -z $("$helper" suggest) ]]
jq '.rotationEnabled=true' "$config" >"$config.tmp"
mv "$config.tmp" "$config"

"$helper" apply beta https://github.com/example/omarchy-beta-theme.git >/dev/null
grep -Fxq 'install:https://github.com/example/omarchy-beta-theme.git' "$log_file"

"$helper" favorite-current >/dev/null
jq -e '.favorites == ["alpha"]' "$config" >/dev/null
"$helper" favorite-current >/dev/null
jq -e '.favorites == []' "$config" >/dev/null
"$helper" favorite beta >/dev/null
"$helper" rotation-mode favorites >/dev/null
: >"$log_file"
"$helper" rotate-now >/dev/null
grep -Fxq 'set:beta' "$log_file"
if grep -q '^set:alpha' "$log_file"; then
  printf 'FAIL: favorites-only rotation selected a non-favorite\n' >&2
  exit 1
fi
"$helper" rotation-mode all >/dev/null
jq -e '.rotationScope == "all"' "$config" >/dev/null

: >"$log_file"
"$helper" rotate-now >/dev/null
grep -Fxq 'set:beta' "$log_file"
if grep -q '^install:' "$log_file"; then
  printf 'FAIL: installed theme was reinstalled during rotation\n' >&2
  exit 1
fi

config_attack_state="$test_root/config-attack-state"
config_attack_runtime="$test_root/config-attack-runtime"
config_victim="$test_root/config-victim"
mkdir -m 700 -p "$config_attack_state/theme-drift" "$config_attack_runtime"
printf 'do not truncate configuration victim\n' >"$config_victim"
ln -s "$config_victim" "$config_attack_state/theme-drift/config.json"
if XDG_STATE_HOME="$config_attack_state" XDG_RUNTIME_DIR="$config_attack_runtime" "$helper" list >/dev/null 2>&1; then
  printf 'FAIL: symlinked configuration was accepted\n' >&2
  exit 1
fi
grep -Fxq 'do not truncate configuration victim' "$config_victim"

lock_attack_runtime="$test_root/lock-attack-runtime"
lock_victim="$test_root/lock-victim"
mkdir -m 700 "$lock_attack_runtime"
printf 'do not truncate lock victim\n' >"$lock_victim"
ln -s "$lock_victim" "$lock_attack_runtime/theme-drift"
if XDG_RUNTIME_DIR="$lock_attack_runtime" "$helper" list >/dev/null 2>&1; then
  printf 'FAIL: symlinked runtime lock directory was accepted\n' >&2
  exit 1
fi
grep -Fxq 'do not truncate lock victim' "$lock_victim"

printf 'PASS: consent and symlink protections hold; approved themes join rotation\n'
