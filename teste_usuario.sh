#!/bin/bash

###############################################################################
# Script de Teste Completo de Privilégios do Usuário
# Valida se o novo usuário tem todos os acessos necessários
# Version: 2.0.0
###############################################################################

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_TESTES=0
TESTES_OK=0
TESTES_FALHA=0

###############################################################################
# FUNÇÕES DE TESTE
###############################################################################

teste_ok() {
    echo -e "${GREEN}[✓ PASSOU]${NC} $1"
    ((TESTES_OK++))
    ((TOTAL_TESTES++))
}

teste_falha() {
    echo -e "${RED}[✗ FALHOU]${NC} $1"
    echo -e "   ${YELLOW}Detalhes: $2${NC}"
    ((TESTES_FALHA++))
    ((TOTAL_TESTES++))
}

teste_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

separador() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

###############################################################################
# TESTES DE IDENTIDADE
###############################################################################

testar_identidade() {
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  1. TESTES DE IDENTIDADE E INFORMAÇÕES BÁSICAS        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # Teste 1: Whoami
    local usuario=$(whoami)
    teste_info "Usuário logado: $usuario"
    
    # Teste 2: UID
    local uid=$(id -u)
    if [[ $uid -ne 0 ]]; then
        teste_ok "UID não é root ($uid) - correto para usuário normal"
    else
        teste_falha "UID é 0 (root)" "Você não deveria estar logado como root diretamente"
    fi
    
    # Teste 3: Grupos
    local grupos=$(groups)
    teste_info "Grupos: $grupos"
    
    if echo "$grupos" | grep -q "sudo"; then
        teste_ok "Usuário está no grupo 'sudo'"
    else
        teste_falha "Usuário NÃO está no grupo 'sudo'" "Necessário para privilégios administrativos"
    fi
    
    # Teste 4: Home directory
    if [[ -d "$HOME" ]] && [[ -w "$HOME" ]]; then
        teste_ok "Home directory existe e é gravável: $HOME"
    else
        teste_falha "Problema com home directory" "Verifique permissões de $HOME"
    fi
    
    # Teste 5: Shell
    local shell=$(echo $SHELL)
    teste_info "Shell: $shell"
    if [[ -x "$shell" ]]; then
        teste_ok "Shell é executável"
    else
        teste_falha "Shell não é executável" "$shell"
    fi
}

###############################################################################
# TESTES DE SUDO
###############################################################################

testar_sudo() {
    separador
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  2. TESTES DE PRIVILÉGIOS SUDO                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # Teste 6: Sudo básico
    if sudo -n whoami &>/dev/null; then
        teste_ok "Sudo sem senha configurado (NOPASSWD)"
    else
        if sudo whoami &>/dev/null; then
            teste_ok "Sudo funciona (com senha)"
        else
            teste_falha "Sudo NÃO funciona" "Execute: sudo visudo e verifique configurações"
        fi
    fi
    
    # Teste 7: Sudo como root
    local sudo_result=$(sudo whoami 2>/dev/null)
    if [[ "$sudo_result" == "root" ]]; then
        teste_ok "Sudo whoami retorna 'root'"
    else
        teste_falha "Sudo whoami NÃO retorna 'root'" "Retornou: $sudo_result"
    fi
    
    # Teste 8: Leitura de arquivos root
    if sudo cat /etc/shadow > /dev/null 2>&1; then
        teste_ok "Pode ler /etc/shadow com sudo"
    else
        teste_falha "NÃO pode ler /etc/shadow" "Privilégios sudo insuficientes"
    fi
    
    # Teste 9: Criação de arquivos em /root
    if sudo touch /root/teste_permissao_$$ 2>/dev/null; then
        sudo rm /root/teste_permissao_$$ 2>/dev/null
        teste_ok "Pode criar arquivos em /root com sudo"
    else
        teste_falha "NÃO pode criar arquivos em /root" "Verifique permissões sudo"
    fi
    
    # Teste 10: Reiniciar serviços
    if sudo systemctl status ssh >/dev/null 2>&1 || sudo systemctl status sshd >/dev/null 2>&1; then
        teste_ok "Pode gerenciar serviços (systemctl) com sudo"
    else
        teste_falha "NÃO pode gerenciar serviços" "Verifique sudo e systemctl"
    fi
}

###############################################################################
# TESTES DE ACESSO A ARQUIVOS
###############################################################################

testar_acesso_arquivos() {
    separador
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  3. TESTES DE ACESSO A ARQUIVOS CRÍTICOS              ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # Teste 11: Leitura SSH config
    if sudo cat /etc/ssh/sshd_config > /dev/null 2>&1; then
        teste_ok "Pode ler /etc/ssh/sshd_config"
    else
        teste_falha "NÃO pode ler SSH config" "Necessário para gerenciar SSH"
    fi
    
    # Teste 12: Edição de arquivos sistema
    if sudo test -w /etc/hosts 2>/dev/null || sudo [ -w /etc/hosts ] 2>/dev/null; then
        teste_ok "Pode editar arquivos do sistema (/etc/hosts)"
    else
        teste_falha "NÃO pode editar /etc/hosts" "Pode precisar de sudo"
    fi
    
    # Teste 13: Logs do sistema
    if sudo cat /var/log/auth.log > /dev/null 2>&1 || sudo cat /var/log/secure > /dev/null 2>&1; then
        teste_ok "Pode ler logs do sistema"
    else
        teste_falha "NÃO pode ler logs" "Verifique /var/log/auth.log ou /var/log/secure"
    fi
}

###############################################################################
# TESTES DE REDE
###############################################################################

testar_rede() {
    separador
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  4. TESTES DE CONFIGURAÇÃO DE REDE                    ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # Teste 14: Ver portas abertas
    if sudo ss -tulnp > /dev/null 2>&1 || sudo netstat -tulnp > /dev/null 2>&1; then
        teste_ok "Pode ver portas abertas (ss/netstat)"
    else
        teste_falha "NÃO pode ver portas abertas" "Necessário para troubleshooting"
    fi
    
    # Teste 15: Configurar firewall
    if command -v ufw &> /dev/null; then
        if sudo ufw status > /dev/null 2>&1; then
            teste_ok "Pode gerenciar firewall UFW"
        else
            teste_falha "NÃO pode gerenciar UFW" "Necessário para segurança"
        fi
    elif command -v iptables &> /dev/null; then
        if sudo iptables -L > /dev/null 2>&1; then
            teste_ok "Pode gerenciar iptables"
        else
            teste_falha "NÃO pode gerenciar iptables" "Necessário para firewall"
        fi
    else
        teste_info "Nenhum firewall detectado (UFW/iptables)"
    fi
}

###############################################################################
# TESTES DE INSTALAÇÃO DE SOFTWARE
###############################################################################

testar_instalacao_software() {
    separador
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  5. TESTES DE INSTALAÇÃO E GERENCIAMENTO DE SOFTWARE  ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # Teste 16: apt/yum update
    if command -v apt-get &> /dev/null; then
        if sudo apt-get update -qq > /dev/null 2>&1; then
            teste_ok "Pode atualizar repositórios APT"
        else
            teste_falha "NÃO pode atualizar APT" "Necessário para instalar software"
        fi
    elif command -v yum &> /dev/null; then
        if sudo yum check-update > /dev/null 2>&1; then
            teste_ok "Pode verificar atualizações YUM"
        else
            teste_falha "NÃO pode usar YUM" "Necessário para instalar software"
        fi
    fi
    
    # Teste 17: Instalar pacote (simulação)
    if command -v apt-get &> /dev/null; then
        if sudo apt-get install --dry-run htop > /dev/null 2>&1; then
            teste_ok "Pode simular instalação de pacotes (apt)"
        else
            teste_falha "NÃO pode simular instalação" "Verifique sudo apt-get"
        fi
    fi
}

###############################################################################
# TESTES DE PROCESSOS
###############################################################################

testar_processos() {
    separador
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  6. TESTES DE GERENCIAMENTO DE PROCESSOS             ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # Teste 18: Ver todos os processos
    if sudo ps aux > /dev/null 2>&1; then
        teste_ok "Pode ver todos os processos (ps aux)"
    else
        teste_falha "NÃO pode ver todos os processos" "Necessário para monitoramento"
    fi
    
    # Teste 19: Kill processos
    # Criamos um processo temporário para testar
    sleep 300 &
    local test_pid=$!
    if sudo kill -0 $test_pid 2>/dev/null; then
        kill $test_pid 2>/dev/null
        teste_ok "Pode enviar sinais para processos (kill)"
    else
        kill $test_pid 2>/dev/null
        teste_falha "NÃO pode enviar sinais para processos" "Necessário para gerenciar serviços"
    fi
}

###############################################################################
# TESTES DE DOCKER (SE INSTALADO)
###############################################################################

testar_docker() {
    separador
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  7. TESTES DE DOCKER (se instalado)                  ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    if ! command -v docker &> /dev/null; then
        teste_info "Docker não instalado - pulando testes"
        return
    fi
    
    # Teste 20: Docker sem sudo
    if docker ps > /dev/null 2>&1; then
        teste_ok "Pode usar Docker SEM sudo (no grupo docker)"
    else
        if sudo docker ps > /dev/null 2>&1; then
            teste_falha "Docker requer sudo" "Adicione usuário ao grupo docker: sudo usermod -aG docker $USER"
        else
            teste_falha "Docker não funciona" "Verifique instalação do Docker"
        fi
    fi
}

###############################################################################
# TESTES DE CHAVES SSH
###############################################################################

testar_chaves_ssh() {
    separador
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  8. TESTES DE CHAVES SSH                              ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # Teste 21: Diretório .ssh existe
    if [[ -d "$HOME/.ssh" ]]; then
        teste_ok "Diretório .ssh existe"
    else
        teste_falha "Diretório .ssh NÃO existe" "Crie com: mkdir -p ~/.ssh; chmod 700 ~/.ssh"
    fi
    
    # Teste 22: authorized_keys existe
    if [[ -f "$HOME/.ssh/authorized_keys" ]]; then
        teste_ok "Arquivo authorized_keys existe"
        
        local num_chaves=$(grep -c "^ssh-" "$HOME/.ssh/authorized_keys" 2>/dev/null || echo "0")
        teste_info "Número de chaves: $num_chaves"
        
        if [[ $num_chaves -gt 0 ]]; then
            teste_ok "$num_chaves chave(s) SSH configurada(s)"
        else
            teste_falha "Nenhuma chave SSH válida" "Adicione chaves em ~/.ssh/authorized_keys"
        fi
    else
        teste_falha "authorized_keys NÃO existe" "Necessário para login SSH"
    fi
    
    # Teste 23: Permissões corretas
    if [[ -d "$HOME/.ssh" ]]; then
        local perm_dir=$(stat -c "%a" "$HOME/.ssh" 2>/dev/null || stat -f "%A" "$HOME/.ssh" 2>/dev/null)
        if [[ "$perm_dir" == "700" ]]; then
            teste_ok "Permissões do .ssh corretas (700)"
        else
            teste_falha "Permissões do .ssh incorretas ($perm_dir)" "Deveria ser 700. Execute: chmod 700 ~/.ssh"
        fi
    fi
    
    if [[ -f "$HOME/.ssh/authorized_keys" ]]; then
        local perm_file=$(stat -c "%a" "$HOME/.ssh/authorized_keys" 2>/dev/null || stat -f "%A" "$HOME/.ssh/authorized_keys" 2>/dev/null)
        if [[ "$perm_file" == "600" ]]; then
            teste_ok "Permissões do authorized_keys corretas (600)"
        else
            teste_falha "Permissões do authorized_keys incorretas ($perm_file)" "Deveria ser 600. Execute: chmod 600 ~/.ssh/authorized_keys"
        fi
    fi
}

###############################################################################
# TESTES DE VARIÁVEIS DE AMBIENTE
###############################################################################

testar_ambiente() {
    separador
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  9. TESTES DE AMBIENTE E VARIÁVEIS                    ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # PATH
    if echo "$PATH" | grep -q "/usr/local/bin"; then
        teste_ok "PATH inclui /usr/local/bin"
    else
        teste_falha "PATH não inclui /usr/local/bin" "Pode afetar execução de comandos"
    fi
    
    # Teste de escrita em tmp
    if touch /tmp/teste_$$ 2>/dev/null; then
        rm /tmp/teste_$$
        teste_ok "Pode escrever em /tmp"
    else
        teste_falha "NÃO pode escrever em /tmp" "Necessário para scripts temporários"
    fi
}

###############################################################################
# RELATÓRIO FINAL
###############################################################################

relatorio_final() {
    separador
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  RELATÓRIO FINAL DOS TESTES                           ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    echo "Total de testes executados: $TOTAL_TESTES"
    echo -e "Testes bem-sucedidos: ${GREEN}$TESTES_OK${NC}"
    echo -e "Testes falhados: ${RED}$TESTES_FALHA${NC}"
    echo ""
    
    local porcentagem=$((TESTES_OK * 100 / TOTAL_TESTES))
    
    if [[ $TESTES_FALHA -eq 0 ]]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ PERFEITO! Todos os testes passaram (100%)${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "O novo usuário tem TODOS os privilégios necessários!"
        echo "Você pode prosseguir com segurança para a Fase 3."
        echo ""
    elif [[ $porcentagem -ge 80 ]]; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}⚠ BOM! A maioria dos testes passou ($porcentagem%)${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Revise os testes que falharam acima."
        echo "Se forem testes opcionais (Docker, etc), você pode prosseguir."
        echo ""
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}✗ ATENÇÃO! Muitos testes falharam ($porcentagem% ok)${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "NÃO prossiga para a Fase 3 ainda!"
        echo "Corrija os problemas identificados nos testes acima."
        echo ""
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

###############################################################################
# EXECUÇÃO PRINCIPAL
###############################################################################

main() {
    clear
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║  SCRIPT DE TESTE COMPLETO DE PRIVILÉGIOS DE USUÁRIO   ║"
    echo "║  Valida se o novo usuário tem acesso root completo    ║"
    echo "║                                                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    echo "Este script vai executar uma série de testes para validar"
    echo "se o usuário atual tem todos os privilégios necessários."
    echo ""
    read -p "Pressione ENTER para iniciar os testes..." pausa
    
    testar_identidade
    testar_sudo
    testar_acesso_arquivos
    testar_rede
    testar_instalacao_software
    testar_processos
    testar_docker
    testar_chaves_ssh
    testar_ambiente
    relatorio_final
}

main