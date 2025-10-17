#!/bin/bash

###############################################################################
# Bootstrap - VM Security Hardening
# Baixa e configura automaticamente os scripts de segurança SSH
# Repository: https://github.com/yesyoudeserve/vm-security
# Version: 2.0.0
###############################################################################

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurações
REPO_URL="https://raw.githubusercontent.com/yesyoudeserve/vm-security/main"
INSTALL_DIR="$HOME/vm-security"

###############################################################################
# FUNÇÕES
###############################################################################

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_step() { echo -e "${CYAN}[→]${NC} $1"; }

banner() {
    clear
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║         VM SECURITY - SSH HARDENING TOOLKIT           ║${NC}"
    echo -e "${CYAN}║         Hardening SSH em 3 Fases Seguras              ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║         github.com/yesyoudeserve/vm-security          ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

verificar_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "NÃO execute este bootstrap como root!"
        echo "Execute como usuário normal: ./bootstrap.sh"
        exit 1
    fi
}

verificar_dependencias() {
    log_step "Verificando dependências..."
    
    local deps_faltando=()
    
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        deps_faltando+=("curl ou wget")
    fi
    
    if ! command -v sudo &> /dev/null; then
        deps_faltando+=("sudo")
    fi
    
    if [[ ${#deps_faltando[@]} -gt 0 ]]; then
        log_error "Dependências faltando: ${deps_faltando[*]}"
        echo ""
        echo "Instale com:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install -y curl sudo"
        exit 1
    fi
    
    log_info "Todas as dependências encontradas"
}

criar_diretorio() {
    log_step "Criando diretório de instalação..."
    
    if [[ -d "$INSTALL_DIR" ]]; then
        log_warning "Diretório já existe: $INSTALL_DIR"
        read -p "Deseja sobrescrever? (sim/não): " resposta
        if [[ "$resposta" =~ ^[Ss][Ii][Mm]$ ]]; then
            rm -rf "$INSTALL_DIR"
        else
            log_error "Instalação cancelada"
            exit 1
        fi
    fi
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    log_info "Diretório criado: $INSTALL_DIR"
}

baixar_arquivo() {
    local arquivo="$1"
    local url="$REPO_URL/$arquivo"
    
    if command -v curl &> /dev/null; then
        curl -sSL -o "$arquivo" "$url"
    elif command -v wget &> /dev/null; then
        wget -q -O "$arquivo" "$url"
    else
        log_error "curl ou wget não encontrado!"
        exit 1
    fi
}

baixar_scripts() {
    log_step "Baixando scripts do repositório..."
    
    local scripts=(
        "ssh_hardening.sh"
        "teste_usuario.sh"
        "corrigir_usuario.sh"
    )
    
    for script in "${scripts[@]}"; do
        echo -n "  Baixando $script... "
        if baixar_arquivo "$script"; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FALHOU${NC}"
            log_error "Erro ao baixar $script"
            exit 1
        fi
    done
    
    log_info "Todos os scripts baixados com sucesso"
}

baixar_documentacao() {
    log_step "Baixando documentação..."
    
    local docs=(
        "README.md"
        "GUIA_RAPIDO.md"
    )
    
    for doc in "${docs[@]}"; do
        baixar_arquivo "$doc" 2>/dev/null || true
    done
    
    log_info "Documentação baixada"
}

configurar_permissoes() {
    log_step "Configurando permissões..."
    
    chmod +x ssh_hardening.sh
    chmod +x teste_usuario.sh
    chmod +x corrigir_usuario.sh
    
    log_info "Permissões configuradas"
}

mostrar_instrucoes() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            INSTALAÇÃO CONCLUÍDA COM SUCESSO!          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📁 Scripts instalados em:${NC}"
    echo "   $INSTALL_DIR"
    echo ""
    echo -e "${CYAN}📋 Arquivos disponíveis:${NC}"
    echo "   • ssh_hardening.sh      - Script principal (3 fases)"
    echo "   • teste_usuario.sh      - Validação de privilégios"
    echo "   • corrigir_usuario.sh   - Correção de usuário existente"
    echo "   • README.md             - Documentação completa"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  PRÓXIMOS PASSOS:${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}1. Configure o Security List na Oracle Cloud:${NC}"
    echo "   • Acesse: https://cloud.oracle.com"
    echo "   • Networking → VCN → Security Lists"
    echo "   • Adicione regra Ingress para a porta que escolher (ex: 49100)"
    echo ""
    echo -e "${BLUE}2. Execute a Fase 1 (Adicionar nova porta SSH):${NC}"
    echo "   ${GREEN}cd $INSTALL_DIR${NC}"
    echo "   ${GREEN}sudo ./ssh_hardening.sh --fase1${NC}"
    echo ""
    echo -e "${BLUE}3. Teste a nova porta em outro terminal${NC}"
    echo ""
    echo -e "${BLUE}4. Execute a Fase 2 (Criar novo usuário):${NC}"
    echo "   ${GREEN}sudo ./ssh_hardening.sh --fase2${NC}"
    echo ""
    echo -e "${BLUE}5. Teste o novo usuário:${NC}"
    echo "   ${GREEN}ssh -p PORTA novo_usuario@seu-ip${NC}"
    echo "   ${GREEN}./teste_usuario.sh${NC}"
    echo ""
    echo -e "${BLUE}6. Execute a Fase 3 (Limpeza final):${NC}"
    echo "   ${GREEN}sudo ./ssh_hardening.sh --fase3${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}📚 Para mais detalhes:${NC}"
    echo "   ${GREEN}cat $INSTALL_DIR/README.md${NC}"
    echo ""
    echo -e "${CYAN}🆘 Precisa de ajuda?${NC}"
    echo "   https://github.com/yesyoudeserve/vm-security/issues"
    echo ""
}

###############################################################################
# EXECUÇÃO PRINCIPAL
###############################################################################

main() {
    banner
    verificar_root
    verificar_dependencias
    criar_diretorio
    baixar_scripts
    baixar_documentacao
    configurar_permissoes
    mostrar_instrucoes
}

main