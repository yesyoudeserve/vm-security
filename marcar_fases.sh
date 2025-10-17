#!/bin/bash

###############################################################################
# Script para marcar fases como concluídas manualmente
# Use quando você já tiver configurado SSH mas não pelo script
# Version: 2.0.0
###############################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ARQUIVO_ESTADO="/root/.ssh_hardening_estado"
BACKUP_DIR="/root/backup_ssh_manual_$(date +%Y%m%d_%H%M%S)"

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "Execute como root: sudo $0"
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  MARCAR FASES COMO CONCLUÍDAS MANUALMENTE             ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Use este script se você JÁ configurou SSH manualmente"
echo "e quer pular direto para uma fase específica."
echo ""

# Detecta configuração atual
echo "Detectando configuração atual..."
echo ""

# Portas SSH
PORTAS_SSH=$(grep "^Port " /etc/ssh/sshd_config 2>/dev/null || echo "")
if [[ -n "$PORTAS_SSH" ]]; then
    echo "Portas SSH configuradas:"
    echo "$PORTAS_SSH"
else
    echo "Portas SSH: padrão (22)"
fi

# Usuários com sudo
echo ""
echo "Usuários com sudo:"
getent group sudo | cut -d: -f4 | tr ',' '\n' | sed 's/^/  • /'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "O que você quer marcar como concluído?"
echo ""
echo "  1) Fase 1 - Tenho porta SSH customizada"
echo "  2) Fase 2 - Tenho usuário novo configurado"
echo "  3) Ambas (Fase 1 + Fase 2)"
echo "  4) Cancelar"
echo ""
read -p "Escolha (1/2/3/4): " opcao

case "$opcao" in
    1)
        echo ""
        read -p "Qual porta SSH customizada está usando? " porta
        
        if ! [[ "$porta" =~ ^[0-9]+$ ]]; then
            log_error "Porta inválida!"
            exit 1
        fi
        
        # Salva estado
        mkdir -p "$(dirname "$ARQUIVO_ESTADO")"
        echo "FASE_1_NOVA_PORTA=concluido" > "$ARQUIVO_ESTADO"
        echo "PORTA_SSH=$porta" >> "$ARQUIVO_ESTADO"
        echo "BACKUP_DIR=$BACKUP_DIR" >> "$ARQUIVO_ESTADO"
        echo "ULTIMA_ATUALIZACAO=$(date +%Y-%m-%d_%H:%M:%S)" >> "$ARQUIVO_ESTADO"
        
        log_info "Fase 1 marcada como concluída (porta $porta)"
        echo ""
        echo "Agora você pode executar:"
        echo "  sudo ./ssh_hardening.sh --fase2"
        ;;
        
    2)
        if [[ ! -f "$ARQUIVO_ESTADO" ]]; then
            log_error "Você precisa marcar Fase 1 primeiro!"
            exit 1
        fi
        
        echo ""
        read -p "Qual o nome do novo usuário? " usuario
        
        if ! id "$usuario" &>/dev/null; then
            log_error "Usuário '$usuario' não existe!"
            exit 1
        fi
        
        # Salva estado
        echo "FASE_2_NOVO_USUARIO=concluido" >> "$ARQUIVO_ESTADO"
        echo "NOVO_USUARIO=$usuario" >> "$ARQUIVO_ESTADO"
        echo "ULTIMA_ATUALIZACAO=$(date +%Y-%m-%d_%H:%M:%S)" >> "$ARQUIVO_ESTADO"
        
        log_info "Fase 2 marcada como concluída (usuário $usuario)"
        echo ""
        echo "Agora você pode executar:"
        echo "  sudo ./ssh_hardening.sh --fase3"
        ;;
        
    3)
        echo ""
        read -p "Qual porta SSH customizada está usando? " porta
        read -p "Qual o nome do novo usuário? " usuario
        
        if ! [[ "$porta" =~ ^[0-9]+$ ]]; then
            log_error "Porta inválida!"
            exit 1
        fi
        
        if ! id "$usuario" &>/dev/null; then
            log_error "Usuário '$usuario' não existe!"
            exit 1
        fi
        
        # Salva estado
        mkdir -p "$(dirname "$ARQUIVO_ESTADO")"
        cat > "$ARQUIVO_ESTADO" << EOF
FASE_1_NOVA_PORTA=concluido
PORTA_SSH=$porta
BACKUP_DIR=$BACKUP_DIR
FASE_2_NOVO_USUARIO=concluido
NOVO_USUARIO=$usuario
ULTIMA_ATUALIZACAO=$(date +%Y-%m-%d_%H:%M:%S)
EOF
        
        log_info "Fases 1 e 2 marcadas como concluídas"
        log_info "Porta: $porta | Usuário: $usuario"
        echo ""
        echo "Agora você pode executar:"
        echo "  sudo ./ssh_hardening.sh --fase3"
        ;;
        
    4)
        log_info "Cancelado"
        exit 0
        ;;
        
    *)
        log_error "Opção inválida!"
        exit 1
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Estado salvo em: $ARQUIVO_ESTADO"
echo ""
echo "Ver estado:"
echo "  cat $ARQUIVO_ESTADO"
echo ""