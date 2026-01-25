#!/bin/bash
# =============================================
# COMMAND: init - Inicialização do orquestrador
# =============================================

cmd_init() {
    log_step "Inicializando orquestrador v3.1..."

    # Validar repositório git
    validate_git_repo || return 1

    # Criar estrutura de diretórios
    ensure_dir "$ORCHESTRATION_DIR"/{tasks,status,logs,pids,archive,checkpoints,.recovery}
    ensure_dir "$AGENTS_DIR"
    ensure_dir "$CLAUDE_DIR/scripts"

    # Criar AGENT_CLAUDE.md base
    create_agent_claude_base

    # Criar PROJECT_MEMORY.md se não existir
    if ! file_exists "$MEMORY_FILE"; then
        create_initial_memory
    fi

    # Criar exemplos se não existirem
    ensure_dir "$ORCHESTRATION_DIR/examples"
    create_example_tasks

    # Inicializar arquivos
    touch "$EVENTS_FILE"

    log_success "Estrutura criada!"

    # Mostrar próximos passos
    echo ""
    echo -e "${CYAN}Próximos passos:${NC}"
    echo ""
    echo "  1. Ver agentes disponíveis:"
    echo "     ${GREEN}$0 agents list${NC}"
    echo ""
    echo "  2. Criar worktrees com agentes:"
    echo "     ${GREEN}$0 setup auth --preset auth${NC}"
    echo ""
    echo "  3. Ou copiar um exemplo de tarefa:"
    echo "     ${GREEN}$0 init-sample${NC}"
    echo ""
    echo "  4. Verificar instalação:"
    echo "     ${GREEN}$0 doctor${NC}"
}

cmd_init_sample() {
    log_step "Copiando exemplos de tarefas..."

    local examples_dir="$ORCHESTRATION_DIR/examples"
    local tasks_dir="$ORCHESTRATION_DIR/tasks"

    if [[ ! -d "$examples_dir" ]] || [[ -z "$(ls -A "$examples_dir" 2>/dev/null)" ]]; then
        create_example_tasks
    fi

    for example in "$examples_dir"/*.md; do
        [[ -f "$example" ]] || continue
        local name=$(basename "$example")
        if [[ ! -f "$tasks_dir/$name" ]]; then
            cp "$example" "$tasks_dir/$name"
            log_success "Copiado: $name"
        else
            log_warn "Já existe: $name (pulando)"
        fi
    done

    log_success "Exemplos copiados para $tasks_dir"
    log_info "Edite as tarefas conforme necessário"
}

# =============================================
# TEMPLATES
# =============================================

create_agent_claude_base() {
    cat > "$CLAUDE_DIR/AGENT_CLAUDE.md" << 'EOF'
# AGENTE EXECUTOR

**VOCÊ NÃO É UM ORQUESTRADOR**

## Identidade
Você é um AGENTE EXECUTOR com uma tarefa específica.
Você possui expertise especializada conforme os agentes carregados.

## Regras Absolutas
1. **NUNCA** crie worktrees ou outros agentes
2. **NUNCA** execute orchestrate.sh
3. **NUNCA** modifique PROJECT_MEMORY.md
4. **FOQUE** exclusivamente na sua tarefa

## Seu Fluxo
1. Criar PROGRESS.md inicial
2. Executar tarefa passo a passo
3. Atualizar PROGRESS.md frequentemente
4. Fazer commits descritivos
5. Criar DONE.md quando terminar

## Arquivos de Status

### PROGRESS.md
```markdown
# Progresso: [tarefa]
## Status: EM ANDAMENTO
## Concluído
- [x] Item
## Pendente
- [ ] Item
## Última Atualização
[DATA]: [descrição]
```

### DONE.md (ao finalizar)
```markdown
# Concluído: [tarefa]
## Resumo
[O que foi feito]
## Arquivos
- path/file.ts - [mudança]
## Como Testar
[Instruções de teste]
```

### BLOCKED.md (se necessário)
```markdown
# Bloqueado: [tarefa]
## Problema
[Descrição]
## Preciso
[O que desbloqueia]
```

## Commits
```
feat(escopo): descrição
fix(escopo): descrição
refactor(escopo): descrição
test(escopo): descrição
```
EOF
}

create_initial_memory() {
    local current_date=$(date '+%Y-%m-%d %H:%M')
    cat > "$MEMORY_FILE" << EOF
# Project Memory v3

> **Última atualização**: $current_date
> **Versão do Orquestrador**: 3.1

## Visão Geral

### Projeto
- **Nome**: $PROJECT_NAME
- **Início**: $(date '+%Y-%m-%d')
- **Repo**: $(git remote get-url origin 2>/dev/null || echo "[local]")

### Stack
| Camada | Tecnologia |
|--------|------------|
| Linguagem | [DEFINIR] |
| Framework | [DEFINIR] |
| Database | [DEFINIR] |

## Roadmap

### Concluído
- [x] Inicialização do projeto

### Em Progresso
_Nenhum_

### Planejado
_A definir_

## Agentes Utilizados

| Orquestração | Data | Agentes |
|--------------|------|---------|
| #0 | $current_date | init |

---
> Atualize com: \`.claude/scripts/orchestrate.sh update-memory\`
EOF
}

create_example_tasks() {
    local examples_dir="$ORCHESTRATION_DIR/examples"
    ensure_dir "$examples_dir"

    # Exemplo: Auth
    cat > "$examples_dir/auth.md" << 'EOF'
# Tarefa: Sistema de Autenticação

## Objetivo
Implementar sistema de autenticação com JWT.

## Requisitos
- [ ] Login com email/senha
- [ ] Registro de usuário
- [ ] Refresh token
- [ ] Logout

## Escopo

### FAZER
- [ ] Modelo de usuário
- [ ] Rotas de auth (/login, /register, /logout)
- [ ] Middleware de autenticação
- [ ] Testes

### NÃO FAZER
- OAuth/Social login (próxima fase)
- 2FA (próxima fase)

## Arquivos
Criar:
- src/auth/
- src/auth/routes.ts
- src/auth/middleware.ts
- src/auth/models/user.ts

## Critérios de Conclusão
- [ ] Testes passando
- [ ] Documentação da API
- [ ] DONE.md criado
EOF

    # Exemplo: API
    cat > "$examples_dir/api-crud.md" << 'EOF'
# Tarefa: API CRUD

## Objetivo
Criar API REST para gerenciamento de recursos.

## Requisitos
- [ ] Endpoints CRUD (Create, Read, Update, Delete)
- [ ] Validação de entrada
- [ ] Paginação
- [ ] Tratamento de erros

## Escopo

### FAZER
- [ ] Rotas REST
- [ ] Validadores
- [ ] Controllers
- [ ] Testes

### NÃO FAZER
- Autenticação (outro worktree)
- Frontend

## Arquivos
Criar:
- src/api/
- src/api/routes.ts
- src/api/controllers/
- src/api/validators/

## Critérios de Conclusão
- [ ] Endpoints funcionando
- [ ] Testes passando
- [ ] DONE.md criado
EOF

    # Exemplo: Frontend
    cat > "$examples_dir/frontend.md" << 'EOF'
# Tarefa: Interface Frontend

## Objetivo
Criar interface de usuário responsiva.

## Requisitos
- [ ] Layout responsivo
- [ ] Componentes reutilizáveis
- [ ] Integração com API
- [ ] Estados de loading/erro

## Escopo

### FAZER
- [ ] Estrutura de componentes
- [ ] Páginas principais
- [ ] Integração com API
- [ ] Estilos

### NÃO FAZER
- Testes E2E (próxima fase)
- Animações complexas

## Arquivos
Criar:
- src/components/
- src/pages/
- src/hooks/
- src/styles/

## Critérios de Conclusão
- [ ] UI funcionando
- [ ] Responsivo
- [ ] DONE.md criado
EOF
}
