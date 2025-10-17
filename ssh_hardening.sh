#!/bin/bash

###############################################################################
# Script de Hardening SSH - MODO INCREMENTAL POR FASES
# Version: 2.0.0 - FINAL
###############################################################################

set -euo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Variáveis
USUARIO_ATUAL="${SUDO_USER:-$(whoami)}"
ARQUIVO_ESTADO="/root/.ssh_hardening_estado"
BACKUP_DIR="/root/backup_ssh_$(date +%Y%m%d_%H%M%S)"

###############################################################################
# FUNÇÕES DE LOG
###############################################################################

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_fase() { echo -e "${MAGENTA}[FASE]${NC} $1"; }

###############################################################################
# GERENCIAMENTO DE ESTADO
###############################################################################

salvar_estado() {
    local fase="$1"
    local dados="$2"
    mkdir -p "$(dirname "$ARQUIVO_ESTADO")"
    if grep -q "^${fase}=" "$ARQUIVO_ESTADO" 2>/dev/null; then
        sed -i "s|^${fase}=.*|${fase}=${dados}|" "$ARQUIVO_ESTADO"
    else
        echo "${fase}=${dados}" >> "$ARQUIVO_ESTADO"
    fi
}

carregar_estado() {
    local fase="$1"
    if [[ -f "$ARQUIVO_ESTADO" ]]; then
        grep "^${fase}=" "$ARQUIVO_ESTADO" 2>/dev/null | cut -d= -f2
    fi
}

verificar_fase_concluida() {
    local fase="$1"
    [[ "$(carregar_estado "$fase")" == "concluido" ]]
}

mostrar_estado_atual() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  ESTADO ATUAL DO HARDENING"
    echo "═══════════════════════════════════════════════════════════"
    
    if [[ ! -f "$ARQUIVO_ESTADO" ]]; then
        echo "  Nenhuma fase executada ainda"
        echo ""
        return
    fi
    
    echo ""
    
    if verificar_fase_concluida "FASE_1_NOVA_PORTA"; then
        local porta=$(carregar_estado "PORTA_SSH")
        echo "  ✓ Fase 1: Nova porta SSH ($porta) - ${GREEN}CONCLUÍDA${NC}"
    else
        echo "  ○ Fase 1: Nova porta SSH - ${YELLOW}PENDENTE${NC}"
    fi
    
    if verificar_fase_concluida "FASE_2_NOVO_USUARIO"; then
        local novo_user=$(carregar_estado "NOVO_USUARIO")
        echo "  ✓ Fase 2: Novo usuário ($novo_user) - ${GREEN}CONCLUÍDA${NC}"
    else
        echo "  ○ Fase 2: Novo usuário - ${YELLOW}PENDENTE${NC}"
    fi
    
    if verificar_fase_concluida "FASE_3_LIMPEZA"; then
        echo "  ✓ Fase 3: Limpeza final - ${GREEN}CONCLUÍDA${NC}"
    else
        echo "  ○ Fase 3: Limpeza final - ${YELLOW}PENDENTE${NC}"
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

###############################################################################
# FASE 1: ADICIONAR NOVA PORTA SSH
###############################################################################

fase1_adicionar_porta() {
    log_fase "FASE 1: Adicionar Nova Porta SSH"
    echo ""
    echo "Esta fase irá:"
    echo "  • Adicionar uma nova porta SSH (mantém a porta 22)"
    echo "  • Configurar firewall para a nova porta"
    echo "  • Desabilitar ssh.socket se necessário"
    echo ""
    echo "⚠️  IMPORTANTE: A porta 22 continuará funcionando!"
    echo ""
    read -p "Deseja continuar com a Fase 1? (sim/não): " resposta
    
    if [[ ! "$resposta" =~ ^[Ss][Ii][Mm]$ ]]; then
        log_info "Fase 1 cancelada"
        return
    fi
    
    # Solicita porta
    local nova_porta=""
    while true; do
        echo ""
        read -p "Digite a nova porta SSH (1024-65535): " nova_porta
        
        if ! [[ "$nova_porta" =~ ^[0-9]+$ ]]; then
            log_error "Digite apenas números!"
            continue
        fi
        
        if [[ "$nova_porta" -lt 1024 ]] || [[ "$nova_porta" -gt 65535 ]]; then
            log_error "Porta deve estar entre 1024 e 65535"
            continue
        fi
        
        if [[ "$nova_porta" -eq 22 ]]; then
            log_error "A porta 22 é a porta atual!"
            continue
        fi
        
        if ss -tuln | grep -q ":$nova_porta " && ! ss -tulnp | grep ":$nova_porta " | grep -q "sshd"; then
            log_error "Porta $nova_porta em uso por outro serviço!"
            continue
        fi
        
        break
    done
    
    log_info "Porta escolhida: $nova_porta"
    
    # Criar backup
    mkdir -p "$BACKUP_DIR"
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup"
    log_info "Backup criado: $BACKUP_DIR"
    
    # Configurar firewall
    log_info "Configurando firewall..."
    if command -v ufw &> /dev/null; then
        ufw allow "$nova_porta/tcp" 2>/dev/null || true
        ufw reload 2>/dev/null || true
    fi
    
    if command -v iptables &> /dev/null; then
        if ! iptables -C INPUT -p tcp --dport "$nova_porta" -j ACCEPT 2>/dev/null; then
            iptables -I INPUT -p tcp --dport "$nova_porta" -j ACCEPT
        fi
    fi
    
    # Adicionar porta ao sshd_config
    log_info "Adicionando porta ao SSH..."
    sed -i '/# HARDENING SSH - FASE/d' /etc/ssh/sshd_config 2>/dev/null || true
    
    cat >> /etc/ssh/sshd_config << EOF

# HARDENING SSH - FASE 1 - $(date +%Y-%m-%d)
Port 22
Port $nova_porta
EOF
    
    # Desabilitar ssh.socket
    if systemctl list-units --full --all | grep -q "ssh.socket"; then
        log_info "Desabilitando ssh.socket..."
        systemctl stop ssh.socket 2>/dev/null || true
        systemctl disable ssh.socket 2>/dev/null || true
    fi
    
    # Testar e aplicar
    if ! sshd -t 2>&1; then
        log_error "Erro na configuração! Revertendo..."
        cp "$BACKUP_DIR/sshd_config.backup" /etc/ssh/sshd_config
        return 1
    fi
    
    log_info "Aplicando configuração..."
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    sleep 3
    
    # Verificar configuração aplicada
    echo ""
    log_info "Verificando configuração aplicada..."
    echo ""
    echo "Configurações de segurança SSH:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Verifica cada configuração crítica
    local config_ok=true
    
    # Porta
    if sudo sshd -T | grep -q "^port $porta$"; then
        echo -e "  ${GREEN}✓${NC} Porta: $porta (porta 22 removida)"
    else
        echo -e "  ${RED}✗${NC} ERRO: Porta não configurada corretamente!"
        config_ok=false
    fi
    
    # Password authentication
    if sudo sshd -T | grep -q "^passwordauthentication no$"; then
        echo -e "  ${GREEN}✓${NC} PasswordAuthentication: no (login por senha DESABILITADO)"
    else
        echo -e "  ${RED}✗${NC} ERRO: Login por senha ainda habilitado!"
        config_ok=false
    fi
    
    # Root login
    if sudo sshd -T | grep -q "^permitrootlogin no$"; then
        echo -e "  ${GREEN}✓${NC} PermitRootLogin: no (root DESABILITADO)"
    else
        echo -e "  ${RED}✗${NC} ERRO: Login root ainda habilitado!"
        config_ok=false
    fi
    
    # Pubkey authentication
    if sudo sshd -T | grep -q "^pubkeyauthentication yes$"; then
        echo -e "  ${GREEN}✓${NC} PubkeyAuthentication: yes (chave SSH HABILITADA)"
    else
        echo -e "  ${RED}✗${NC} ERRO: Chave SSH não habilitada!"
        config_ok=false
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [[ "$config_ok" == false ]]; then
        log_error "Algumas configurações não foram aplicadas corretamente!"
        log_error "Revertendo para backup..."
        cp "$backup_dir/sshd_config.fase3" /etc/ssh/sshd_config
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
        return 1
    fi
    
    # Verificar portas
    echo ""
    echo "Portas SSH ativas:"
    ss -tulnp | grep sshd
    echo ""
    
    if ! ss -tuln | grep -q ":$nova_porta "; then
        log_error "Nova porta NÃO está ativa!"
        return 1
    fi
    
    log_info "✓ Nova porta $nova_porta está ATIVA!"
    log_info "✓ Porta 22 ainda ATIVA!"
    
    # Salvar estado
    salvar_estado "FASE_1_NOVA_PORTA" "concluido"
    salvar_estado "PORTA_SSH" "$nova_porta"
    salvar_estado "BACKUP_DIR" "$BACKUP_DIR"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    log_info "FASE 1 CONCLUÍDA COM SUCESSO!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "🧪 TESTE AGORA (em outro terminal):"
    echo ""
    local ip=$(curl -s -m 5 ifconfig.me 2>/dev/null || echo "SEU_IP")
    echo "   ${BLUE}ssh -i /caminho/sua-chave.pem -p $nova_porta $USUARIO_ATUAL@$ip${NC}"
    echo ""
    echo "📌 PRÓXIMO PASSO:"
    echo "   ${BLUE}sudo $0 --fase2${NC}"
    echo ""
}

###############################################################################
# FASE 2: CRIAR NOVO USUÁRIO
###############################################################################

fase2_criar_usuario() {
    if ! verificar_fase_concluida "FASE_1_NOVA_PORTA"; then
        log_error "Execute a Fase 1 primeiro!"
        return 1
    fi
    
    log_fase "FASE 2: Criar Novo Usuário"
    echo ""
    echo "Esta fase irá:"
    echo "  • Criar um novo usuário com privilégios sudo"
    echo "  • Copiar suas chaves SSH para o novo usuário"
    echo ""
    read -p "Deseja continuar? (sim/não): " resposta
    
    if [[ ! "$resposta" =~ ^[Ss][Ii][Mm]$ ]]; then
        log_info "Fase 2 cancelada"
        return
    fi
    
    # Solicita nome
    local novo_usuario=""
    while true; do
        echo ""
        read -p "Digite o nome do novo usuário: " novo_usuario
        
        if [[ -z "$novo_usuario" ]] || [[ "$novo_usuario" == "root" ]] || [[ "$novo_usuario" == "$USUARIO_ATUAL" ]]; then
            log_error "Nome inválido!"
            continue
        fi
        
        if id "$novo_usuario" &>/dev/null; then
            log_warning "Usuário já existe!"
            read -p "Usar este usuário? (sim/não): " usar
            [[ "$usar" =~ ^[Ss][Ii][Mm]$ ]] && break
            continue
        fi
        
        break
    done
    
    log_info "Usuário: $novo_usuario"
    
    # Criar usuário
    if ! id "$novo_usuario" &>/dev/null; then
        adduser --disabled-password --gecos "" "$novo_usuario"
        log_info "✓ Usuário criado"
    fi
    
    # Adicionar ao sudo
    usermod -aG sudo "$novo_usuario"
    log_info "✓ Sudo habilitado"
    
    # Configurar sudo sem senha (NOPASSWD)
    log_info "Configurando sudo sem senha..."
    echo "$novo_usuario ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$novo_usuario"
    chmod 440 /etc/sudoers.d/"$novo_usuario"
    
    # Testa sintaxe do sudoers
    if visudo -c -f /etc/sudoers.d/"$novo_usuario" &>/dev/null; then
        log_info "✓ Sudo sem senha configurado (NOPASSWD)"
    else
        log_warning "Erro na configuração do sudoers"
        rm -f /etc/sudoers.d/"$novo_usuario"
    fi
    
    # Adicionar ao grupo docker (se existir)
    if command -v docker &> /dev/null; then
        if getent group docker > /dev/null 2>&1; then
            usermod -aG docker "$novo_usuario"
            log_info "✓ Adicionado ao grupo docker"
        else
            log_warning "Docker instalado mas grupo 'docker' não existe"
        fi
    else
        log_info "Docker não instalado (ok)"
    fi
    
    # Copiar chaves
    local ssh_dir_novo="/home/$novo_usuario/.ssh"
    mkdir -p "$ssh_dir_novo"
    
    local user_home_atual
    if [[ "$USUARIO_ATUAL" == "root" ]]; then
        user_home_atual="/root"
    else
        user_home_atual="/home/$USUARIO_ATUAL"
    fi
    
    if [[ -f "$user_home_atual/.ssh/authorized_keys" ]]; then
        cp "$user_home_atual/.ssh/authorized_keys" "$ssh_dir_novo/authorized_keys"
        log_info "✓ Chaves copiadas"
    fi
    
    chown -R "$novo_usuario:$novo_usuario" "$ssh_dir_novo"
    chmod 700 "$ssh_dir_novo"
    chmod 600 "$ssh_dir_novo/authorized_keys" 2>/dev/null || true
    
    # Salvar estado
    salvar_estado "FASE_2_NOVO_USUARIO" "concluido"
    salvar_estado "NOVO_USUARIO" "$novo_usuario"
    
    local porta=$(carregar_estado "PORTA_SSH")
    local ip=$(curl -s -m 5 ifconfig.me 2>/dev/null || echo "SEU_IP")
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    log_info "FASE 2 CONCLUÍDA!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "🧪 TESTE AGORA:"
    echo "   ${BLUE}ssh -i /caminho/sua-chave.pem -p $porta $novo_usuario@$ip${NC}"
    echo ""
    echo "📌 PRÓXIMO PASSO:"
    echo "   ${BLUE}sudo $0 --fase3${NC}"
    echo ""
}

###############################################################################
# FASE 3: LIMPEZA E HARDENING FINAL
###############################################################################

fase3_limpeza_final() {
    if ! verificar_fase_concluida "FASE_1_NOVA_PORTA" || ! verificar_fase_concluida "FASE_2_NOVO_USUARIO"; then
        log_error "Execute as Fases 1 e 2 primeiro!"
        return 1
    fi
    
    log_fase "FASE 3: Limpeza e Hardening Final"
    echo ""
    echo "Esta fase irá:"
    echo "  • Desabilitar login por senha"
    echo "  • Desabilitar login root"
    echo "  • Remover porta 22"
    echo ""
    
    local porta=$(carregar_estado "PORTA_SSH")
    local usuario=$(carregar_estado "NOVO_USUARIO")
    
    log_warning "⚠️  Certifique-se que testou:"
    log_warning "  1. Acesso na porta $porta"
    log_warning "  2. Acesso com usuário $usuario"
    echo ""
    
    read -p "Você testou tudo? (sim/não): " resposta
    if [[ ! "$resposta" =~ ^[Ss][Ii][Mm]$ ]]; then
        log_info "Fase 3 cancelada"
        return
    fi
    
    read -p "Digite 'CONFIRMO' para prosseguir: " conf
    if [[ "$conf" != "CONFIRMO" ]]; then
        log_info "Cancelado"
        return
    fi
    
    # Backup
    local backup_dir=$(carregar_estado "BACKUP_DIR")
    cp /etc/ssh/sshd_config "$backup_dir/sshd_config.fase3"
    
    # Aplicar hardening
    log_info "Aplicando hardening final..."
    
    # Remove TODAS as configurações antigas
    sed -i '/# HARDENING SSH/d' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i '/^Port 22$/d' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i '/^Port /d' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i '/^PasswordAuthentication /d' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i '/^ChallengeResponseAuthentication /d' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i '/^PubkeyAuthentication /d' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i '/^PermitRootLogin /d' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i '/^MaxAuthTries /d' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i '/^PermitEmptyPasswords /d' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i '/^UsePAM /d' /etc/ssh/sshd_config 2>/dev/null || true
    
    cat >> /etc/ssh/sshd_config << EOF

# HARDENING SSH - CONFIGURAÇÃO FINAL - $(date +%Y-%m-%d)
# Apenas porta customizada (porta 22 REMOVIDA)
Port $porta

# DESABILITA login por senha - apenas chave SSH permitida
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitEmptyPasswords no
UsePAM yes
PubkeyAuthentication yes

# DESABILITA login root
PermitRootLogin no

# Configurações de segurança extras
MaxAuthTries 3
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
    
    if ! sshd -t 2>&1; then
        log_error "Erro! Revertendo..."
        cp "$backup_dir/sshd_config.fase3" /etc/ssh/sshd_config
        return 1
    fi
    
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    sleep 3
    
    # Remover porta 22 do firewall
    if command -v ufw &> /dev/null; then
        ufw delete allow 22/tcp 2>/dev/null || true
    fi
    
    # Desabilitar usuário antigo
    read -p "Desabilitar usuário $USUARIO_ATUAL? (sim/não): " desab
    if [[ "$desab" =~ ^[Ss][Ii][Mm]$ ]]; then
        usermod -L "$USUARIO_ATUAL"
        deluser "$USUARIO_ATUAL" sudo 2>/dev/null || true
        log_info "✓ Usuário $USUARIO_ATUAL desabilitado"
    fi
    
    salvar_estado "FASE_3_LIMPEZA" "concluido"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    log_info "HARDENING SSH COMPLETO!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "📋 CONFIGURAÇÃO FINAL DE SEGURANÇA:"
    echo ""
    echo "  🔐 AUTENTICAÇÃO:"
    echo "     • Porta SSH: ${BLUE}$porta${NC} (porta padrão 22 REMOVIDA)"
    echo "     • Login por SENHA: ${RED}DESABILITADO ✗${NC}"
    echo "     • Login por CHAVE SSH: ${GREEN}HABILITADO ✓${NC}"
    echo "     • Login ROOT: ${RED}DESABILITADO ✗${NC}"
    echo ""
    echo "  👤 USUÁRIOS:"
    echo "     • Usuário ativo: ${GREEN}$usuario${NC}"
    echo "     • Privilégios sudo: ${GREEN}SEM SENHA (NOPASSWD)${NC}"
    
    if [[ "$(carregar_estado "USUARIO_ANTIGO_DESABILITADO")" == "sim" ]]; then
        echo "     • Usuário $USUARIO_ATUAL: ${RED}DESABILITADO${NC}"
    else
        echo "     • Usuário $USUARIO_ATUAL: ${YELLOW}AINDA ATIVO${NC}"
    fi
    
    echo ""
    echo "  🔒 POLÍTICAS DE SEGURANÇA:"
    echo "     • Tentativas de login: máximo 3"
    echo "     • Timeout de login: 60 segundos"
    echo "     • Keep-alive: 300 segundos"
    echo ""
    echo "  🔥 FIREWALL:"
    echo "     • Porta $porta: ${GREEN}LIBERADA${NC}"
    echo "     • Porta 22: ${RED}REMOVIDA${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "⚠️  AÇÕES MANUAIS NECESSÁRIAS:"
    echo ""
    echo "  1. ${YELLOW}Remova porta 22 do Security List da Oracle Cloud${NC}"
    echo "     • Acesse: https://cloud.oracle.com"
    echo "     • Networking → VCN → Security Lists"
    echo "     • DELETE a regra de Ingress da porta 22"
    echo ""
    echo "  2. ${YELLOW}Atualize suas ferramentas/scripts${NC}"
    echo "     • Use porta $porta em vez de 22"
    echo "     • Use usuário $usuario em vez de $USUARIO_ATUAL"
    echo ""
    echo "  3. ${YELLOW}Teste o acesso novamente${NC}"
    echo "     • ssh -i sua-chave.pem -p $porta $usuario@seu-ip"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "💾 BACKUPS SALVOS EM:"
    echo "   $backup_dir"
    echo ""
    echo "🎉 PARABÉNS! Seu servidor está agora significativamente mais seguro!"
    echo ""
}

###############################################################################
# MENU PRINCIPAL
###############################################################################

mostrar_menu() {
    clear
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║     HARDENING SSH - MODO INCREMENTAL                  ║"
    echo "╚════════════════════════════════════════════════════════╝"
    
    mostrar_estado_atual
    
    echo "OPÇÕES:"
    echo ""
    echo "  1) Fase 1: Adicionar nova porta SSH"
    echo "  2) Fase 2: Criar novo usuário"
    echo "  3) Fase 3: Limpeza e hardening final"
    echo ""
    echo "  0) Sair"
    echo ""
}

main() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Execute como root: sudo $0"
        exit 1
    fi
    
    case "${1:-}" in
        --fase1) fase1_adicionar_porta; exit 0 ;;
        --fase2) fase2_criar_usuario; exit 0 ;;
        --fase3) fase3_limpeza_final; exit 0 ;;
    esac
    
    while true; do
        mostrar_menu
        read -p "Escolha: " opcao
        
        case "$opcao" in
            1) fase1_adicionar_porta; read -p "ENTER..." ;;
            2) fase2_criar_usuario; read -p "ENTER..." ;;
            3) fase3_limpeza_final; read -p "ENTER..." ;;
            0) exit 0 ;;
            *) log_error "Opção inválida!"; sleep 2 ;;
        esac
    done
}

main "$@"