#!/usr/bin/env bash
# ==============================================================================
# AAPP Companion Management (lib/cmd_companion.sh)
#
# Governed by Plan P-90 (Companion Repository Bridge).
# Manages cross-repository co-development bridges across 3 topologies:
#   - checkout: registers an existing local checkout where it is
#   - worktree: dedicated worktree for non-AAPP repository
#   - clone: dedicated clone under .workspace/companion/<name>
# ==============================================================================
set -e

_companion_canonicalize() {
    local p="$1"
    case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
    local out="" seg
    local IFS=/
    for seg in $p; do
        case "$seg" in
            ''|.) continue ;;
            ..)   out="${out%/*}" ;;
            *)    out="$out/$seg" ;;
        esac
    done
    printf '%s\n' "${out:-/}"
}

_companion_remove_allow_path() {
    local target="$1"
    local current_paths=() p
    while IFS= read -r p; do
        [ -n "$p" ] && [ "$p" != "$target" ] && current_paths+=("$p")
    done < <(git config --get-all aapp.allowPath 2>/dev/null || true)

    git config --unset-all aapp.allowPath 2>/dev/null || true
    for p in "${current_paths[@]}"; do
        git config --add aapp.allowPath "$p"
    done
}

_companion_get_all_names() {
    git config --get-regexp '^aapp\.companion\..*\.path$' 2>/dev/null | \
        sed -E 's/^aapp\.companion\.([^.]+)\.path.*/\1/' || true
}

cmd_companion_add() {
    local name="${1:-}"
    local path_or_url="${2:-}"
    local opt="${3:-}"

    if [ -z "$name" ] || [ -z "$path_or_url" ]; then
        echo "❌ [Companion] Usage: aapp companion add <name> <path> [worktree] | aapp companion add <name> <url>" >&2
        return 1
    fi

    # Name validation: lowercase alphanumeric, dashes, underscores
    if [[ ! "$name" =~ ^[a-z0-9_-]+$ ]]; then
        echo "❌ [Companion] Invalid companion name '$name': must contain only lowercase alphanumeric characters, dashes, or underscores." >&2
        return 1
    fi

    # Refuse duplicates
    local existing_path
    existing_path="$(git config "aapp.companion.$name.path" 2>/dev/null || true)"
    if [ -n "$existing_path" ]; then
        echo "❌ [Companion] Companion '$name' is already registered at '$existing_path'." >&2
        return 1
    fi

    # Determine mode
    local mode="checkout"
    if [ "$opt" = "worktree" ]; then
        mode="worktree"
    elif [[ "$path_or_url" =~ ^(https?://|git@|ssh://) ]] || [[ "$path_or_url" =~ \.git$ && ! -d "$path_or_url" ]]; then
        mode="clone"
    fi

    case "$mode" in
        checkout)
            if [ ! -d "$path_or_url" ] || ! git -C "$path_or_url" rev-parse --git-dir >/dev/null 2>&1; then
                echo "❌ [Companion] Path '$path_or_url' is not a valid Git repository." >&2
                return 1
            fi
            local abs_path
            abs_path="$(_companion_canonicalize "$path_or_url")"
            git config "aapp.companion.$name.path" "$abs_path"
            git config "aapp.companion.$name.mode" "checkout"
            git config --add aapp.allowPath "$abs_path"
            echo "🔗 [Companion] Registered '$name' (checkout) at $abs_path."
            ;;

        worktree)
            if [ ! -d "$path_or_url" ] || ! git -C "$path_or_url" rev-parse --git-dir >/dev/null 2>&1; then
                echo "❌ [Companion] Path '$path_or_url' is not a valid Git repository." >&2
                return 1
            fi
            local abs_source
            abs_source="$(_companion_canonicalize "$path_or_url")"

            # G2 Refusal Rule: refuse AAPP repository
            if [ -f "$abs_source/aapp" ] || [ -d "$abs_source/.agents" ] || [ -d "$abs_source/.plans" ]; then
                echo "❌ [Companion] $path_or_url uses AAPP. Raw worktrees lack linked kit hooks. Start the plan in $path_or_url ('aapp start <id>') and register its worktree here: 'aapp companion add $name <path-to-worktree>'." >&2
                return 1
            fi

            local wt_dest="$PWD/.workspace/companion/$name"
            if [ -d "$wt_dest" ]; then
                echo "❌ [Companion] Destination '$wt_dest' already exists." >&2
                return 1
            fi
            mkdir -p "$PWD/.workspace/companion"
            git -C "$abs_source" worktree add "$wt_dest" HEAD >/dev/null 2>&1 || git -C "$abs_source" worktree add "$wt_dest" >/dev/null 2>&1
            local canon_dest
            canon_dest="$(_companion_canonicalize "$wt_dest")"
            git config "aapp.companion.$name.path" "$canon_dest"
            git config "aapp.companion.$name.mode" "worktree"
            git config --add aapp.allowPath "$canon_dest"
            echo "🌳 [Companion] Created worktree for '$name' at $canon_dest."
            ;;

        clone)
            local clone_dest="$PWD/.workspace/companion/$name"
            if [ -d "$clone_dest" ]; then
                echo "❌ [Companion] Destination '$clone_dest' already exists." >&2
                return 1
            fi
            mkdir -p "$PWD/.workspace/companion"
            git clone -q "$path_or_url" "$clone_dest"
            local canon_clone
            canon_clone="$(_companion_canonicalize "$clone_dest")"
            git config "aapp.companion.$name.path" "$canon_clone"
            git config "aapp.companion.$name.mode" "clone"
            git config --add aapp.allowPath "$canon_clone"
            echo "📦 [Companion] Cloned '$name' into $canon_clone."
            ;;
    esac
    return 0
}

cmd_companion_status() {
    local target="${1:-}"
    local names=()
    if [ -n "$target" ]; then
        local p
        p="$(git config "aapp.companion.$target.path" 2>/dev/null || true)"
        if [ -z "$p" ]; then
            echo "❌ [Companion] Companion '$target' not found." >&2
            return 1
        fi
        names=("$target")
    else
        while IFS= read -r n; do
            [ -n "$n" ] && names+=("$n")
        done < <(_companion_get_all_names)
    fi

    if [ ${#names[@]} -eq 0 ]; then
        echo "No companion repositories registered. Run 'aapp companion add' to register one."
        return 0
    fi

    for n in "${names[@]}"; do
        local c_path c_mode branch dirty ahead=0 behind=0 fetched_at=""
        c_path="$(git config "aapp.companion.$n.path" 2>/dev/null || true)"
        c_mode="$(git config "aapp.companion.$n.mode" 2>/dev/null || echo "unknown")"

        if [ ! -d "$c_path" ]; then
            printf "  • %-14s [%s] missing at %s\n" "$n" "$c_mode" "$c_path"
            continue
        fi

        branch="$(git -C "$c_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")"
        dirty="$(git -C "$c_path" status --porcelain 2>/dev/null | wc -l)"

        if git -C "$c_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
            local counts
            counts="$(git -C "$c_path" rev-list --left-right --count "HEAD...@{u}" 2>/dev/null || echo "0 0")"
            ahead="$(echo "$counts" | awk '{print $1}')"
            behind="$(echo "$counts" | awk '{print $2}')"
        fi

        local git_dir
        git_dir="$(git -C "$c_path" rev-parse --git-dir 2>/dev/null || true)"
        case "$git_dir" in /*) ;; *) git_dir="$c_path/$git_dir" ;; esac
        if [ -f "$git_dir/FETCH_HEAD" ]; then
            fetched_at="$(stat -c %y "$git_dir/FETCH_HEAD" 2>/dev/null | cut -d'.' -f1 || true)"
        fi

        printf "  • %-14s [%s] (%s) -> ahead: %d, behind: %d, dirty: %d%s\n" \
            "$n" "$c_mode" "$branch" "$ahead" "$behind" "$dirty" "${fetched_at:+ (fetched: $fetched_at)}"
    done
    return 0
}

cmd_companion_push() {
    local name="${1:-}"
    if [ -z "$name" ]; then
        echo "❌ [Companion] Usage: aapp companion push <name>" >&2
        return 1
    fi

    local c_path
    c_path="$(git config "aapp.companion.$name.path" 2>/dev/null || true)"
    if [ -z "$c_path" ] || [ ! -d "$c_path" ]; then
        echo "❌ [Companion] Companion '$name' not found." >&2
        return 1
    fi

    local dirty
    dirty="$(git -C "$c_path" status --porcelain 2>/dev/null | wc -l)"
    if [ "$dirty" -gt 0 ]; then
        echo "❌ [Companion] '$name' has $dirty uncommitted changes; commit or stash before push." >&2
        return 1
    fi

    if ! git -C "$c_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        echo "❌ [Companion] '$name' has no configured upstream tracking branch." >&2
        return 1
    fi

    git -C "$c_path" push
}

cmd_companion_remove() {
    local name="${1:-}"
    local force="${2:-}"

    if [ -z "$name" ]; then
        echo "❌ [Companion] Usage: aapp companion remove <name> [force]" >&2
        return 1
    fi

    local c_path c_mode
    c_path="$(git config "aapp.companion.$name.path" 2>/dev/null || true)"
    c_mode="$(git config "aapp.companion.$name.mode" 2>/dev/null || echo "checkout")"

    if [ -z "$c_path" ]; then
        echo "❌ [Companion] Companion '$name' not found." >&2
        return 1
    fi

    if [ "$c_mode" = "checkout" ]; then
        _companion_remove_allow_path "$c_path"
        git config --unset-all "aapp.companion.$name.path" 2>/dev/null || true
        git config --unset-all "aapp.companion.$name.mode" 2>/dev/null || true
        echo "🔓 [Companion] Unregistered '$name' (checkout preserved at $c_path)."
        return 0
    fi

    # worktree or clone: check for uncommitted changes or unpushed commits
    local dirty=0 ahead=0
    if [ -d "$c_path" ]; then
        dirty="$(git -C "$c_path" status --porcelain 2>/dev/null | wc -l)"
        if git -C "$c_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
            ahead="$(git -C "$c_path" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
        else
            ahead="$(git -C "$c_path" rev-list --count HEAD 2>/dev/null || echo 0)"
        fi
    fi

    if [ "$force" != "force" ] && { [ "$dirty" -gt 0 ] || [ "$ahead" -gt 0 ]; }; then
        echo "❌ [Companion] '$name' has uncommitted changes ($dirty) or unpushed commits ($ahead)." >&2
        echo "   Use 'aapp companion remove $name force' to remove anyway." >&2
        return 1
    fi

    if [ -d "$c_path" ]; then
        if [ "$c_mode" = "worktree" ]; then
            git -C "$c_path" worktree remove --force "$c_path" >/dev/null 2>&1 || rm -rf "$c_path"
        else
            rm -rf "$c_path"
        fi
    fi

    _companion_remove_allow_path "$c_path"
    git config --unset-all "aapp.companion.$name.path" 2>/dev/null || true
    git config --unset-all "aapp.companion.$name.mode" 2>/dev/null || true
    echo "🗑️  [Companion] Removed companion '$name' ($c_mode at $c_path)."
    return 0
}

cmd_companion_list() {
    local names=()
    while IFS= read -r n; do
        [ -n "$n" ] && names+=("$n")
    done < <(_companion_get_all_names)

    if [ ${#names[@]} -eq 0 ]; then
        echo "No companion repositories registered."
        return 0
    fi

    for n in "${names[@]}"; do
        local c_path c_mode branch="unknown"
        c_path="$(git config "aapp.companion.$n.path" 2>/dev/null || true)"
        c_mode="$(git config "aapp.companion.$n.mode" 2>/dev/null || echo "unknown")"
        if [ -d "$c_path" ]; then
            branch="$(git -C "$c_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")"
        fi
        printf "%-14s [%-8s] (%s) %s\n" "$n" "$c_mode" "$branch" "$c_path"
    done
    return 0
}

cmd_companion() {
    local sub="${1:-list}"
    shift || true

    case "$sub" in
        add)
            cmd_companion_add "$@"
            ;;
        status)
            cmd_companion_status "$@"
            ;;
        push)
            cmd_companion_push "$@"
            ;;
        remove|rm)
            cmd_companion_remove "$@"
            ;;
        list|ls)
            cmd_companion_list "$@"
            ;;
        help|-h|--help)
            echo "aapp companion add <name> <path> [worktree] | aapp companion add <name> <url>"
            echo "aapp companion status [name]"
            echo "aapp companion push <name>"
            echo "aapp companion remove <name> [force]"
            echo "aapp companion list"
            ;;
        *)
            echo "❌ [Companion] Unknown subcommand '$sub'. Run 'aapp companion help'." >&2
            return 1
            ;;
    esac
}
