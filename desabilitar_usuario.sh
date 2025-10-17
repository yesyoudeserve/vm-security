#!/bin/bash

###############################################################################
# Script para desabilitar usuário antigo completamente
# Version: 2.0.0
###############################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "Execute como root: sudo $0 NOME_USUARIO"
    exit 1
fi

if [[ -z "${1:-}" ]]; then
    log_error "Uso: sudo $0 NOME_USUARIO"
    echo ""
    echo "Exemplo: sudo $0 ubuntu"
    echo ""
    echo "Este script irá:"
    echo "  • Bloquear a senha do usuário"
    echo "  • Remover do grupo sudo"
    echo "  • Desabilitar chaves SSH"
    echo "  • Impedir qualquer login futuro"
    exit 1
fi

USUARIO="$1"
USUARIO_ATUAL=$(whoami)

# Verifica se usuário existe
if ! id "$USUARIO" &>/dev/null; then
    log_error "Usuário '$USUARIO' não existe!"
    exit 1
fi

# Impede desabilitar o próprio usuário logado
if [[ "$USUARIO" == "$USUARIO_ATUAL" ]] || [[ "$USUARIO" == "${SUDO_USER:-}" ]]; then
    log_error "PERIGO! Você está tentando desabilitar o usuário que está usando!"
    log_error "Faça login com outro usuário primeiro."
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  DESABILITAR USUÁRIO COMPLETAMENTE                    ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Usuário a desabilitar: $USUARIO"
echo ""
echo "⚠️  ATENÇÃO: Esta ação irá:"
echo ""
echo "  1. Bloquear a senha do usuário"
echo "  2. Remover privilégios sudo"
echo "  3. Desabilitar chaves SSH (impede login)"
echo "  4. Impedir qualquer acesso futuro"
echo ""
echo "O usuário NÃO será deletado (arquivos mantidos)."
echo ""

read -p "Tem certeza que deseja desabilitar '$USUARIO'? (sim/não): " confirma

if [[ ! "$confirma" =~ ^[Ss][Ii][Mm]$ ]]; then
    log_info "Operação cancelada"
    exit 0
fi

echo ""
log_info "Desabilitando usuário $USUARIO..."
echo ""

# 1. Bloqueia senha
log_info "Bloqueando senha..."
if usermod -L "$USUARIO" 2>/dev/null; then
    echo "  ✓ Senha bloqueada"
else
    log_warning "Não foi possível bloquear senha (talvez já esteja bloqueada)"
fi

# 2. Remove do grupo sudo
log_info "Removendo privilégios sudo..."
if deluser "$USUARIO" sudo 2>/dev/null; then
    echo "  ✓ Removido do grupo sudo"
elif gpasswd -d "$USUARIO" sudo 2>/dev/null; then
    echo "  ✓ Removido do grupo sudo (via gpasswd)"
else
    log_warning "Usuário não estava no grupo sudo"
fi

# 3. Remove/desabilita chaves SSH
log_info "Desabilitando chaves SSH..."

user_home=""
if [[ "$USUARIO" == "root" ]]; then
    user_home="/root"
else
    user_home="/home/$USUARIO"
fi

if [[ -f "$user_home/.ssh/authorized_keys" ]]; then
    # Faz backup primeiro
    mv "$user_home/.ssh/authorized_keys" "$user_home/.ssh/authorized_keys.disabled.$(date +%Y%m%d_%H%M%S)"
    echo "  ✓ Chaves SSH movidas para .disabled"
    echo "  ✓ Backup salvo em $user_home/.ssh/"
else
    log_warning "Nenhuma chave SSH encontrada"
fi

# 4. Remove arquivo sudoers específico se existir
if [[ -f "/etc/sudoers.d/$USUARIO" ]]; then
    rm -f "/etc/sudoers.d/$USUARIO"
    echo "  ✓ Configuração sudoers removida"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "USUÁRIO $USUARIO COMPLETAMENTE DESABILITADO!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✓ O usuário não pode mais fazer login"
echo "✓ Não tem mais privilégios sudo"
echo "✓ Chaves SSH desabilitadas"
echo ""
echo "💾 Arquivos do usuário mantidos em: $user_home"
echo ""
echo "🔍 TESTE AGORA (em outro terminal):"
echo "   ssh -i chave.pem -p PORTA $USUARIO@IP"
echo "   Deve retornar: Permission denied"
echo ""
echo "♻️  PARA REVERTER (se necessário):"
echo "   sudo usermod -U $USUARIO"
echo "   sudo usermod -aG sudo $USUARIO"
echo "   sudo mv $user_home/.ssh/authorized_keys.disabled.* $user_home/.ssh/authorized_keys"
echo ""