#!/bin/bash
# =============================================
# GIT - Operações Git e Worktree
# =============================================

# =============================================
# INFORMAÇÕES DO REPOSITÓRIO
# =============================================

is_git_clean() {
    git diff --quiet HEAD 2>/dev/null && git diff --cached --quiet HEAD 2>/dev/null
}

current_branch() {
    git branch --show-current 2>/dev/null || echo "main"
}

default_branch() {
    git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
}

branch_exists() {
    local branch=$1
    git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null
}

# =============================================
# OPERAÇÕES DE WORKTREE
# =============================================

# Lista worktrees do orquestrador
list_worktrees() {
    local prefix="${PROJECT_NAME}-"

    git worktree list 2>/dev/null | while read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        local name=$(basename "$path")

        # Filtrar apenas worktrees do orquestrador
        if [[ "$name" == "$prefix"* ]]; then
            echo "${name#$prefix}"
        fi
    done
}

# Verifica se worktree existe
worktree_exists() {
    local name=$1
    local worktree_path="../${PROJECT_NAME}-$name"
    dir_exists "$worktree_path"
}

# Cria worktree
create_git_worktree() {
    local name=$1
    local from_branch=${2:-$(current_branch)}
    local worktree_path="../${PROJECT_NAME}-$name"
    local branch="feature/$name"

    # Validar nome
    validate_name "$name" "worktree" || return 1

    # Verificar se já existe
    if worktree_exists "$name"; then
        log_warn "Worktree já existe: $name"
        return 0
    fi

    # Verificar branch de origem
    if ! branch_exists "$from_branch"; then
        log_error "Branch de origem não existe: $from_branch"
        return 1
    fi

    log_info "Criando worktree: $name (de $from_branch)"

    # Marcar para cleanup em caso de erro
    CLEANUP_NEEDED=true
    CLEANUP_WORKTREE="$worktree_path"

    # Criar branch e worktree
    if branch_exists "$branch"; then
        log_info "Branch $branch já existe, usando existente"
        git worktree add "$worktree_path" "$branch" || {
            log_error "Falha ao criar worktree"
            return 1
        }
    else
        git worktree add -b "$branch" "$worktree_path" "$from_branch" || {
            log_error "Falha ao criar worktree"
            return 1
        }
    fi

    # Desmarcar cleanup
    CLEANUP_NEEDED=false
    CLEANUP_WORKTREE=""

    log_success "Worktree criada: $worktree_path"
    return 0
}

# Remove worktree
remove_git_worktree() {
    local name=$1
    local force=${2:-false}
    local worktree_path="../${PROJECT_NAME}-$name"

    if ! worktree_exists "$name"; then
        log_warn "Worktree não existe: $name"
        return 0
    fi

    # Verificar mudanças não commitadas
    if [[ "$force" != "true" ]]; then
        local uncommitted=$(cd "$worktree_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [[ $uncommitted -gt 0 ]]; then
            log_warn "Worktree tem $uncommitted arquivo(s) não commitado(s)"
            if ! confirm "Remover mesmo assim? Mudanças serão perdidas."; then
                return 1
            fi
        fi
    fi

    log_info "Removendo worktree: $name"

    git worktree remove "$worktree_path" --force 2>/dev/null || {
        log_error "Falha ao remover worktree"
        return 1
    }

    log_success "Worktree removida: $name"
    return 0
}

# =============================================
# OPERAÇÕES DE MERGE
# =============================================

# Simula merge para verificar conflitos
simulate_merge() {
    local branch=$1
    local target=${2:-main}

    if ! branch_exists "$branch"; then
        log_error "Branch não existe: $branch"
        return 1
    fi

    # Criar branch temporária
    local temp_branch="merge-test-$(date +%s)"
    git checkout -b "$temp_branch" "$target" 2>/dev/null || return 1

    # Tentar merge
    if git merge --no-commit --no-ff "$branch" 2>/dev/null; then
        git merge --abort 2>/dev/null || true
        git checkout - 2>/dev/null
        git branch -D "$temp_branch" 2>/dev/null
        return 0
    else
        git merge --abort 2>/dev/null || true
        git checkout - 2>/dev/null
        git branch -D "$temp_branch" 2>/dev/null
        return 1
    fi
}

# Faz merge de branch
merge_branch() {
    local branch=$1
    local target=${2:-main}
    local message=${3:-"Merge $branch into $target"}

    if ! branch_exists "$branch"; then
        log_error "Branch não existe: $branch"
        return 1
    fi

    log_info "Merging $branch into $target..."

    git checkout "$target" 2>/dev/null || {
        log_error "Falha ao mudar para $target"
        return 1
    }

    if git merge "$branch" -m "$message"; then
        log_success "Merge concluído: $branch"
        return 0
    else
        log_error "Conflito no merge de $branch"
        return 1
    fi
}

# =============================================
# INFORMAÇÕES DE COMMIT
# =============================================

# Conta commits desde branch
count_commits_since() {
    local branch=${1:-main}
    git rev-list --count HEAD ^"$branch" 2>/dev/null || echo 0
}

# Lista arquivos modificados desde branch
files_changed_since() {
    local branch=${1:-main}
    git diff --name-only "$branch" 2>/dev/null
}

# Último commit
last_commit() {
    git log --oneline -1 2>/dev/null || echo "nenhum"
}
