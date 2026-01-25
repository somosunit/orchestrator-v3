#!/bin/bash
# =============================================
# COMMAND: merge/cleanup - Finalização
# =============================================

cmd_merge() {
    local target=${1:-main}

    log_step "Iniciando merge para: $target"

    # Verificar conclusão de todas as tarefas
    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local worktree_path="../${PROJECT_NAME}-$name"

        # Pular reviews
        [[ "$name" == review-* ]] && continue

        if ! file_exists "$worktree_path/DONE.md"; then
            log_error "Agente $name não terminou (sem DONE.md)"
            log_info "Use: $0 verify $name"
            return 1
        fi
    done

    # Mudar para branch alvo
    git checkout "$target" || {
        log_error "Falha ao mudar para $target"
        return 1
    }

    git pull origin "$target" 2>/dev/null || true

    local merged=0
    local failed=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue
        local name=$(basename "$task_file" .md)
        local branch="feature/$name"

        # Pular reviews
        [[ "$name" == review-* ]] && continue

        log_info "Merging $branch..."

        if git merge "$branch" -m "feat: merge $name"; then
            log_success "$branch merged"
            ((merged++))
        else
            log_error "Conflito em $branch"
            log_info "Resolva manualmente:"
            log_info "  git status"
            log_info "  # resolver conflitos"
            log_info "  git add ."
            log_info "  git commit"
            ((failed++))

            if ! confirm "Continuar com próximo merge?"; then
                return 1
            fi
        fi
    done

    if [[ $failed -eq 0 ]]; then
        log_success "Merge completo! ($merged branches)"
    else
        log_warn "Merge parcial: $merged OK, $failed com conflitos"
    fi

    # Registrar evento
    echo "[$(timestamp)] MERGED: $merged branches to $target" >> "$EVENTS_FILE"
}

cmd_cleanup() {
    log_step "Limpando worktrees..."

    # Confirmar operação destrutiva
    if ! confirm "Remover todas as worktrees? Dados não commitados serão perdidos."; then
        log_info "Operação cancelada"
        return 0
    fi

    local archive_dir="$ORCHESTRATION_DIR/archive/$(date '+%Y%m%d_%H%M%S')"
    ensure_dir "$archive_dir"

    local removed=0

    for task_file in "$ORCHESTRATION_DIR/tasks"/*.md; do
        [[ -f "$task_file" ]] || continue

        local name=$(basename "$task_file" .md)
        local worktree_path="../${PROJECT_NAME}-$name"

        # Parar agente se rodando
        stop_agent_process "$name" true 2>/dev/null || true

        # Arquivar artefatos
        cp "$worktree_path/DONE.md" "$archive_dir/${name}_DONE.md" 2>/dev/null || true
        cp "$worktree_path/PROGRESS.md" "$archive_dir/${name}_PROGRESS.md" 2>/dev/null || true
        cp "$worktree_path/BLOCKED.md" "$archive_dir/${name}_BLOCKED.md" 2>/dev/null || true
        cp "$worktree_path/.claude/AGENTS_USED" "$archive_dir/${name}_AGENTS.txt" 2>/dev/null || true

        # Remover worktree
        if git worktree remove "$worktree_path" --force 2>/dev/null; then
            log_success "Removido: $name"
            ((removed++))
        else
            log_warn "Falha ao remover: $name"
        fi

        # Mover tarefa para arquivo
        mv "$task_file" "$archive_dir/"
    done

    # Limpar logs e PIDs
    rm -f "$ORCHESTRATION_DIR/logs"/*.log
    rm -f "$ORCHESTRATION_DIR/pids"/*

    # Limpar worktrees órfãs
    git worktree prune 2>/dev/null

    log_success "Cleanup completo! ($removed worktrees removidas)"
    log_info "Artefatos arquivados em: $archive_dir"

    # Registrar evento
    echo "[$(timestamp)] CLEANUP: $removed worktrees archived" >> "$EVENTS_FILE"
}

cmd_show_memory() {
    if file_exists "$MEMORY_FILE"; then
        cat "$MEMORY_FILE"
    else
        log_error "PROJECT_MEMORY.md não encontrado"
        return 1
    fi
}

cmd_update_memory() {
    log_step "Atualizando memória..."

    if ! file_exists "$MEMORY_FILE"; then
        log_error "PROJECT_MEMORY.md não encontrado"
        return 1
    fi

    local current_date=$(date '+%Y-%m-%d %H:%M')

    # Usar escape seguro para sed
    local escaped_date=$(escape_sed "$current_date")

    # Atualizar timestamp
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s|> \*\*Última atualização\*\*:.*|> **Última atualização**: $escaped_date|" "$MEMORY_FILE"
    else
        sed -i "s|> \*\*Última atualização\*\*:.*|> **Última atualização**: $escaped_date|" "$MEMORY_FILE"
    fi

    log_success "Memória atualizada"
}
