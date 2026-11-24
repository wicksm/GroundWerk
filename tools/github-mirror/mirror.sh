#!/usr/bin/env bash
# Mirrors main and the tags of one Azure Repos repo to its copy on GitHub (GATE-6, GATE-12,
# docs/adr/0013). It copies them from the repo's checkout into a new bare repo and rewrites the
# whole history there: each of PRIVATE_RENAMES in every file, path, message and name, and every
# author, committer and tagger address to GITHUB_NOREPLY. It stops if another address is left, if
# one of PRIVATE_WORDS is in what it would push or if gitleaks finds a secret, and pushes main and
# the tags to GITHUB_OWNER's repo of the same name with its deploy key. The rewrite gives the same
# commits on every run, so each push only adds to the mirror, and it never forces one.
#
# Usage: mirror.sh <repo> <deploy key>
#   <repo>        the folder of the repo's full checkout, named after the repo, with origin/main
#                 and the tags fetched
#   <deploy key>  the private key of the GitHub repo's deploy key, which has write access
# Needs GITHUB_OWNER, GITHUB_NOREPLY, PRIVATE_WORDS and PRIVATE_RENAMES, which pipeline
# mirror-to-github's own variables set, and git filter-repo and gitleaks on PATH, which
# pipelines/mirror-to-github.yml installs. PRIVATE_WORDS lists the words that must never reach
# GitHub, such as the project's old name, separated by commas, each matched in any case, or, if it
# starts word:, only as a whole word in its own case. PRIVATE_RENAMES lists renames of the form
# old=new, separated by commas, such as each form of the old name with the new one's. A rename whose
# old text starts word: changes it only as a whole word, not inside a longer one. A whole word is
# one with no letter, digit or underscore next to it. Both are variables so that this public script
# holds neither.
set -euo pipefail

repo="$1"
key="$2"

if [[ ! "${GITHUB_OWNER:-}" =~ ^[A-Za-z0-9-]+$ ]]; then
  echo "GITHUB_OWNER must be the GitHub account the mirrors belong to." >&2
  exit 1
fi
if [[ ! "${GITHUB_NOREPLY:-}" =~ ^([0-9]+\+)?[A-Za-z0-9-]+@users\.noreply\.github\.com$ ]]; then
  echo "GITHUB_NOREPLY must be that account's no-reply address, ending @users.noreply.github.com." >&2
  exit 1
fi
if [[ ! "${PRIVATE_WORDS:-}" =~ ^(word:)?[A-Za-z0-9._-]{3,}(,(word:)?[A-Za-z0-9._-]{3,})*$ ]]; then
  echo "PRIVATE_WORDS must list the words that must never reach GitHub, separated by commas," \
    "each of 3 or more letters, digits, dots, dashes or underscores, and each may start word:." >&2
  exit 1
fi
rename='(word:)?[A-Za-z0-9 ._/-]{3,}=[A-Za-z0-9 ._/-]+'
if [[ ! "${PRIVATE_RENAMES:-}" =~ ^$rename(,$rename)*$ ]]; then
  echo "PRIVATE_RENAMES must list renames of the form old=new, separated by commas, each old" \
    "text of 3 or more and each new one of 1 or more letters, digits, spaces, dots, underscores," \
    "slashes or dashes, and each old text may start word:." >&2
  exit 1
fi
IFS=',' read -r -a private_words <<<"$PRIVATE_WORDS"
IFS=',' read -r -a private_renames <<<"$PRIVATE_RENAMES"
any_case=()
whole_words=()
for word in "${private_words[@]}"; do
  if [[ "$word" == word:* ]]; then
    whole_words+=("${word#word:}")
  else
    any_case+=("$word")
  fi
done
holds_word() { # <text>: whether it holds one of PRIVATE_WORDS
  local word
  for word in "${any_case[@]}"; do
    if [[ "${1,,}" == *"${word,,}"* ]]; then
      return 0
    fi
  done
  for word in "${whole_words[@]}"; do
    if [[ "$1" =~ (^|[^A-Za-z0-9_])${word//./\\.}([^A-Za-z0-9_]|$) ]]; then
      return 0
    fi
  done
  return 1
}

checkout="$(cd "$repo" && pwd)"
name="$(basename "$checkout")"
if holds_word "$name"; then
  echo "The repo's name holds one of PRIVATE_WORDS, so nothing was pushed." >&2
  exit 1
fi
destination="git@github.com:$GITHUB_OWNER/$name.git"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mirror="$work/mirror.git"
# grep's -w takes the same whole words as holds_word, since in the C locale only letters, digits
# and underscores make up a word
if ((${#any_case[@]} > 0)); then
  printf '%s\n' "${any_case[@]}" >"$work/any-case"
fi
if ((${#whole_words[@]} > 0)); then
  printf '%s\n' "${whole_words[@]}" >"$work/whole-words"
fi
file_holds_word() { # <file>: whether it holds one of PRIVATE_WORDS
  local words status
  for words in any-case whole-words; do
    if [[ ! -s "$work/$words" ]]; then
      continue
    fi
    status=0
    if [[ "$words" == any-case ]]; then
      LC_ALL=C grep -a -i -F -f "$work/$words" -- "$1" >/dev/null || status=$?
    else
      LC_ALL=C grep -a -w -F -f "$work/$words" -- "$1" >/dev/null || status=$?
    fi
    if ((status == 0)); then
      return 0
    elif ((status > 1)); then
      echo "The search for PRIVATE_WORDS failed, so nothing was pushed." >&2
      exit 1
    fi
  done
  return 1
}

# Only main and the tags
git init --quiet --bare "$mirror"
git -C "$mirror" fetch --quiet --no-tags "$checkout" \
  '+refs/remotes/origin/main:refs/heads/main' '+refs/tags/*:refs/tags/*'

# The renames in filter-repo's own form: plain ones as they are, word: ones as a regex that
# matches only where no letter, digit or underscore is next to the old text. filter-repo makes
# them in text files, but not in binary files, and in commit and tag messages, and the callbacks
# below make them in the same order in paths and in author, committer and tagger names: the plain
# ones first, then the word: ones, each in the order listed.
for rename in "${private_renames[@]}"; do
  old="${rename%%=*}"
  new="${rename#*=}"
  if [[ "$old" == word:* ]]; then
    old="${old#word:}"
    printf 'regex:(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])==>%s\n' "${old//./\\.}" "$new"
  else
    printf '%s==>%s\n' "$old" "$new"
  fi
done >"$work/renames"
export MIRROR_RENAMES="$work/renames"
renames_callback() { # <argument>: a filter-repo callback body that makes the renames in it
  cat <<CALLBACK
global renames
if "renames" not in globals():
  renames = []
  with open(os.environ["MIRROR_RENAMES"], "rb") as file:
    for line in file.read().splitlines():
      old, new = line.rsplit(b"==>", 1)
      renames.append((re.compile(old[6:]) if old.startswith(b"regex:") else old, new))
  renames.sort(key=lambda rename: not isinstance(rename[0], bytes))
for old, new in renames:
  $1 = $1.replace(old, new) if isinstance(old, bytes) else old.sub(new, $1)
return $1
CALLBACK
}

# The renames everywhere, and every author, committer and tagger address becomes the no-reply one.
# Every commit stays, even one that only made renames and so changes nothing now. If filter-repo
# stops, such as when two paths in a commit would get the same name, its output is shown unless it
# holds one of PRIVATE_WORDS.
if ! git -C "$mirror" filter-repo --quiet --force --prune-empty never --prune-degenerate never \
  --replace-text "$work/renames" --replace-message "$work/renames" \
  --filename-callback "$(renames_callback filename)" --name-callback "$(renames_callback name)" \
  --email-callback 'return os.environb[b"GITHUB_NOREPLY"]' >"$work/filter-repo.log" 2>&1; then
  if ! file_holds_word "$work/filter-repo.log"; then
    cat "$work/filter-repo.log" >&2
  fi
  echo "git filter-repo failed, so nothing was pushed." >&2
  exit 1
fi

# The renames change only the past: main's files go public as they are today
today="$(git -C "$checkout" rev-parse 'refs/remotes/origin/main^{tree}')"
if [[ "$(git -C "$mirror" rev-parse 'main^{tree}')" != "$today" ]]; then
  echo "PRIVATE_RENAMES would change main's files as they are today, so nothing was pushed." >&2
  exit 1
fi

# Stop if another address is left, or a name holds an address, without printing either
addresses="$(
  git -C "$mirror" log --format='%ae%n%ce' main --tags
  git -C "$mirror" for-each-ref --format='%(taggeremail:trim)' refs/tags
)"
if grep -v -x -F -e "$GITHUB_NOREPLY" -e '' <<<"$addresses" >/dev/null; then
  echo "A commit or tag still has another address, so nothing was pushed." >&2
  exit 1
fi
names="$(
  git -C "$mirror" log --format='%an%n%cn' main --tags
  git -C "$mirror" for-each-ref --format='%(taggername)' refs/tags
)"
if grep -F '@' <<<"$names" >/dev/null; then
  echo "A commit's or tag's name holds an address, so nothing was pushed." >&2
  exit 1
fi

# Stop if one of PRIVATE_WORDS is in anything it would push: a path, a file, a commit's message or
# names, or a tag's name, message or tagger. It says where, naming a commit by its ID in Azure
# DevOps, and never prints the word.
azure_id() { # <commit>: its ID in Azure DevOps, from filter-repo's map of old IDs to new ones
  local old new
  while read -r old new; do
    if [[ "$new" == "$1" ]] && git -C "$checkout" cat-file -e "$old^{commit}" 2>/dev/null; then
      echo "$old"
      return
    fi
  done <"$mirror/filter-repo/commit-map"
  echo "$1"
}
found=()
git -C "$mirror" for-each-ref --format='%(refname)' refs/heads/main refs/tags >"$work/refs"
if file_holds_word "$work/refs"; then
  found+=("a tag's name")
fi
git -C "$mirror" rev-list --objects main --tags |
  git -C "$mirror" cat-file --batch-check='%(objecttype) %(objectname) %(rest)' >"$work/objects"
# Every path in every commit, since rev-list names an object only by the first path it meets it at
git -C "$mirror" rev-list main --tags >"$work/commits"
while read -r commit; do git -C "$mirror" ls-tree -r --name-only "$commit"; done <"$work/commits" |
  sort -u >"$work/paths"
if file_holds_word "$work/paths"; then
  found+=("a path")
fi
git -C "$mirror" for-each-ref --format='%(objectname) %(refname:strip=2)' refs/tags >"$work/tags"
while read -r type id path; do
  if [[ "$type" != blob && "$type" != commit && "$type" != tag ]]; then
    continue
  fi
  git -C "$mirror" cat-file "$type" "$id" >"$work/object"
  if file_holds_word "$work/object"; then
    case "$type" in
      blob)
        # The oldest commit that has it: parents before children, the first commit's files and
        # merges included
        commits="$(git -C "$mirror" -c log.showRoot=true log -m --reverse --topo-order --format=%H \
          --find-object="$id" main --tags)"
        commit="$(azure_id "${commits%%$'\n'*}")"
        if holds_word "$path"; then
          found+=("a file in commit $commit, at a path that holds one too")
        else
          found+=("file $path, in commit $commit")
        fi
        ;;
      commit) found+=("commit $(azure_id "$id"): its message, author or committer") ;;
      tag)
        tag="$(awk -v id="$id" '$1 == id { print $2 }' "$work/tags")"
        if holds_word "$tag"; then
          found+=("an annotated tag whose name holds one too")
        else
          found+=("tag $tag: its message or tagger")
        fi
        ;;
    esac
  fi
done <"$work/objects"
if ((${#found[@]} > 0)); then
  echo "One of PRIVATE_WORDS is in what would be pushed, so nothing was pushed. It's in:" >&2
  printf -- '- %s\n' "${found[@]}" >&2
  exit 1
fi

# Stop if gitleaks finds a secret anywhere in main's history or the tags. It says where, naming each
# commit by its ID in Azure DevOps, and never prints the secret.
printf '%s' $'{{ range . }}{{ .RuleID }} {{ .Commit }} {{ .File }}:{{ .StartLine }}\n{{ end }}' >"$work/leaks.tmpl"
if ! gitleaks git --no-banner --redact --log-opts='main --tags' --report-format template \
  --report-template "$work/leaks.tmpl" --report-path "$work/leaks" "$mirror"; then
  if [[ ! -s "$work/leaks" ]]; then
    echo "gitleaks failed, so nothing was pushed." >&2
    exit 1
  fi
  echo "gitleaks found a secret, so nothing was pushed. It's in:" >&2
  while read -r rule commit place; do
    echo "- $place, in commit $(azure_id "$commit"), by rule $rule" >&2
  done <"$work/leaks"
  exit 1
fi

# Push main and the tags over SSH with the deploy key, trusting only GitHub's published host key
chmod 600 "$key"
echo 'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl' >"$work/known_hosts"
export GIT_SSH_COMMAND="ssh -i '$key' -o IdentitiesOnly=yes -o UserKnownHostsFile='$work/known_hosts' -o StrictHostKeyChecking=yes -o BatchMode=yes"
git -C "$mirror" push --quiet --atomic "$destination" 'refs/heads/main:refs/heads/main' 'refs/tags/*:refs/tags/*'

# Check that the mirror's main and tags are now exactly these
expected="$(git -C "$mirror" for-each-ref --format='%(objectname) %(refname)' refs/heads/main refs/tags | sort)"
actual="$(git -C "$mirror" ls-remote "$destination" 'refs/heads/*' 'refs/tags/*' | grep -v '\^{}$' | tr '\t' ' ' | sort)"
if [[ "$actual" != "$expected" ]]; then
  echo "The mirror's branches or tags differ from what was pushed." >&2
  exit 1
fi
echo "$name: mirrored main and $(git -C "$mirror" tag | wc -l) tags, $(git -C "$mirror" rev-list --count main) commits on main, every address the no-reply one"
