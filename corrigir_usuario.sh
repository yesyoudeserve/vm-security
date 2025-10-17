#!/bin/bash

###############################################################################
# Script para corrigir usuário já criado na Fase 2
# Adiciona: NOPASSWD sudo + grupo docker
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
    log_error "Execute como root: sudo $0 usuario"
    exit 1
fi

if [[ -z "${1:-}" ]]; then
    log_error "Uso: sudo $0 NOME_DO_USUARIO"
    echo ""
    echo "Exemplo: sudo $0 admin"
    exit 1
fi

USUARIO="$1"

if ! id "$USUARIO" &>/dev/null; then
    log_error "Usuário '$USUARIO' não existe!"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  CORREÇÃO DE PRIVILÉGIOS DO USUÁRIO: $USUARIO"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. Configurar sudo sem senha
log_info "Configurando sudo sem senha (NOPASSWD)..."
echo "$USUARIO ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$USUARIO"
chmod 440 /etc/sudoers.d/"$USUARIO"

if visudo -c -f /etc/sudoers.d/"$USUARIO" &>/dev/null; then
    log_info "✓ Sudo sem senha configurado"
else
    log_error "Erro na configuração do sudoers"
    rm -f /etc/sudoers.d/"$USUARIO"
    exit 1
fi

# 2. Adicionar ao grupo docker (se existir)
if command -v docker &> /dev/null; then
    if getent group docker > /dev/null 2>&1; then
        usermod -aG docker "$USUARIO"
        log_info "✓ Adicionado ao grupo docker"
        log_warning "O usuário precisa RELOGAR para que o grupo docker tenha efeito"
    else
        log_warning "Docker instalado mas grupo 'docker' não existe"
        log_info "Criando grupo docker..."
        groupadd docker 2>/dev/null || true
        usermod -aG docker "$USUARIO"
        log_info "✓ Grupo docker criado e usuário adicionado"
    fi
else
    log_info "Docker não instalado (não é necessário)"
fi

# 3. Verificar se está no grupo sudo
if groups "$USUARIO" | grep -q sudo; then
    log_info "✓ Usuário já está no grupo sudo"
else
    log_warning "Adicionando ao grupo sudo..."
    usermod -aG sudo "$USUARIO"
    log_info "✓ Adicionado ao grupo sudo"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
log_info "CORREÇÃO CONCLUÍDA!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Configurações aplicadas:"
echo "  ✓ Sudo sem senha (NOPASSWD)"
echo "  ✓ Grupo sudo"
if command -v docker &> /dev/null; then
    echo "  ✓ Grupo docker"
fi
echo ""
echo "⚠️  IMPORTANTE:"
echo "   Se você estava logado com o usuário $USUARIO,"
echo "   faça LOGOUT e LOGIN novamente para que o grupo"
echo "   docker tenha efeito!"
echo ""
echo "Teste agora:"
echo "  1. Faça login: ssh -p PORTA $USUARIO@IP"
echo "  2. Teste sudo: sudo whoami (não deve pedir senha)"
if command -v docker &> /dev/null; then
    echo "  3. Teste docker: docker ps (não deve pedir sudo)"
fi
echo ""