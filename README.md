# 🔒 VM Security - SSH Hardening Toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Version-2.0.0-blue.svg)](https://github.com/yesyoudeserve/vm-security)
[![Bash](https://img.shields.io/badge/Bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)
[![Oracle Cloud](https://img.shields.io/badge/Oracle%20Cloud-Ready-red.svg)](https://www.oracle.com/cloud/)

Toolkit completo para hardening SSH em VMs Oracle Cloud (e outras) usando abordagem **incremental em 3 fases**, garantindo **zero risco de lockout**.

## 📋 Índice

- [Características](#-características)
- [Por que usar?](#-por-que-usar)
- [Instalação Rápida](#-instalação-rápida)
- [Uso Passo a Passo](#-uso-passo-a-passo)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Segurança](#-segurança)
- [Troubleshooting](#-troubleshooting)
- [Contribuindo](#-contribuindo)
- [Licença](#-licença)

## ✨ Características

### 🎯 Abordagem Incremental em 3 Fases

- **Fase 1**: Adiciona nova porta SSH (mantém porta 22 ativa)
- **Fase 2**: Cria novo usuário com privilégios completos
- **Fase 3**: Remove porta 22 e finaliza hardening

### 🛡️ Segurança Máxima

- ✅ Desabilita login por senha (apenas chave SSH)
- ✅ Desabilita login root
- ✅ Porta SSH customizada (não-padrão)
- ✅ Sudo sem senha (NOPASSWD) para automação
- ✅ Configuração de firewall automática (UFW + iptables)
- ✅ Correção automática de ssh.socket

### 🔄 Idempotente e Seguro

- ✅ Pode ser executado múltiplas vezes sem problemas
- ✅ Sistema de estado para rastrear progresso
- ✅ Backups automáticos antes de cada mudança
- ✅ Scripts de rollback incluídos
- ✅ Validação de configuração em cada passo

### 🧪 Testes Integrados

- ✅ Script de validação de privilégios (25+ testes)
- ✅ Verificação automática de sudo, docker, SSH, etc.
- ✅ Relatório detalhado de aprovação/falhas

## 🤔 Por que usar?

### Problema Comum

Ao fazer hardening SSH, é fácil:
- 🚫 Se trancar fora da VM
- 🚫 Perder acesso root/sudo
- 🚫 Quebrar configurações existentes
- 🚫 Não testar adequadamente antes de finalizar

### A Solução

Este toolkit usa uma abordagem **incremental com testes entre cada fase**:

```
┌─────────────┐    Teste    ┌─────────────┐    Teste    ┌─────────────┐
│   FASE 1    │   ────────→ │   FASE 2    │   ────────→ │   FASE 3    │
│ Nova Porta  │             │ Novo User   │             │  Finaliza   │
│  (22+nova)  │             │ (22+nova+u) │             │  (só nova)  │
└─────────────┘             └─────────────┘             └─────────────┘
```

A qualquer momento, você ainda tem acesso pela porta 22 até confirmar que tudo funciona!

## 🚀 Instalação Rápida

### Método 1: Bootstrap Automático (Recomendado)

```bash
# Baixa e executa o instalador
curl -sSL https://raw.githubusercontent.com/yesyoudeserve/vm-security/main/bootstrap.sh | bash

# OU usando wget
wget -qO- https://raw.githubusercontent.com/yesyoudeserve/vm-security/main/bootstrap.sh | bash
```

### Método 2: Clone Manual

```bash
git clone https://github.com/yesyoudeserve/vm-security.git
cd vm-security
chmod +x *.sh
```

## 📖 Uso Passo a Passo

### Pré-requisitos

1. **VM Oracle Cloud** (ou qualquer VM Ubuntu/Debian)
2. **Acesso SSH atual** funcionando
3. **Chave SSH** configurada
4. **Privilégios sudo**

### ⚠️ ANTES DE COMEÇAR

**CRÍTICO**: Configure o Security List na Oracle Cloud primeiro!

```
1. Acesse: https://cloud.oracle.com
2. Menu → Networking → Virtual Cloud Networks
3. Clique na sua VCN → Security Lists → Default Security List
4. Add Ingress Rule:
   - Source CIDR: 0.0.0.0/0
   - IP Protocol: TCP
   - Destination Port: [sua porta escolhida, ex: 49100]
5. Salvar
```

### 🎯 Fase 1: Adicionar Nova Porta SSH

```bash
cd ~/vm-security
sudo ./ssh_hardening.sh --fase1
```

**O que acontece:**
- Solicita a nova porta SSH (ex: 49100)
- Adiciona a porta ao SSH (mantém porta 22)
- Configura firewall (UFW + iptables)
- Desabilita ssh.socket
- Cria backup completo

**⚠️ TESTE OBRIGATÓRIO:**

Em **outro terminal**, teste a conexão:

```bash
ssh -i /caminho/sua-chave.pem -p 49100 seu-usuario@seu-ip
```

✅ **Funcionou?** Continue para Fase 2
❌ **Não funcionou?** Você ainda tem acesso pela porta 22!

### 👤 Fase 2: Criar Novo Usuário

```bash
sudo ./ssh_hardening.sh --fase2
```

**O que acontece:**
- Solicita nome do novo usuário
- Cria usuário com privilégios sudo
- Configura sudo SEM SENHA (NOPASSWD)
- Adiciona ao grupo docker (se instalado)
- Copia suas chaves SSH

**⚠️ TESTE OBRIGATÓRIO:**

1. Faça login com o novo usuário:

```bash
ssh -i /caminho/sua-chave.pem -p 49100 novo-usuario@seu-ip
```

2. Execute o script de testes:

```bash
cd ~/vm-security
./teste_usuario.sh
```

3. Verifique o relatório:

```
╔════════════════════════════════════════════════════════╗
║  RELATÓRIO FINAL DOS TESTES                           ║
╚════════════════════════════════════════════════════════╝

Total de testes executados: 25
Testes bem-sucedidos: 25
Testes falhados: 0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ PERFEITO! Todos os testes passaram (100%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

O novo usuário tem TODOS os privilégios necessários!
Você pode prosseguir com segurança para a Fase 3.
```

✅ **100% de aprovação?** Continue para Fase 3
⚠️ **< 80%?** Revise os erros antes de continuar

### 🏁 Fase 3: Limpeza e Hardening Final

```bash
sudo ./ssh_hardening.sh --fase3
```

**⚠️ ATENÇÃO**: Esta fase é **irreversível** (remove porta 22)!

**O que acontece:**
- Remove porta 22 do SSH
- Remove porta 22 do firewall
- Desabilita login por senha
- Desabilita login root
- Aplica políticas de segurança
- Opção de desabilitar usuário antigo

**Após conclusão:**

1. ✅ Remova porta 22 do Security List da Oracle Cloud
2. ✅ Teste acesso final com novo usuário e porta
3. ✅ Atualize seus scripts/ferramentas

## 📁 Estrutura do Projeto

```
vm-security/
├── bootstrap.sh              # Instalador automático
├── ssh_hardening.sh          # Script principal (3 fases)
├── teste_usuario.sh          # Validação de privilégios
├── corrigir_usuario.sh       # Correção de usuário existente
├── README.md                 # Documentação completa
├── GUIA_RAPIDO.md           # Guia de referência rápida
└── LICENSE                   # Licença MIT
```

## 🔐 Segurança

### O que este toolkit faz:

- ✅ **Porta SSH não-padrão**: Reduz ataques automatizados
- ✅ **Apenas chave SSH**: Força bruta impossível
- ✅ **Root desabilitado**: Não pode fazer login como root
- ✅ **Sudo NOPASSWD**: Seguro em ambientes cloud com chave SSH
- ✅ **Firewall configurado**: Apenas portas necessárias abertas

### O que este toolkit NÃO faz:

- ❌ Não configura fail2ban (recomendado adicionar)
- ❌ Não configura 2FA (opcional para segurança extra)
- ❌ Não monitora logs em tempo real
- ❌ Não faz backup de dados (apenas configs)

### Recomendações Adicionais

Após o hardening, considere:

```bash
# Instalar fail2ban
sudo apt-get install fail2ban -y

# Configurar atualizações automáticas
sudo apt-get install unattended-upgrades -y

# Monitorar logs
sudo apt-get install logwatch -y
```

## 🧪 Testes

### Script de Teste Automático

O `teste_usuario.sh` verifica:

| Categoria | Testes |
|-----------|--------|
| Identidade | UID, grupos, home, shell |
| Sudo | NOPASSWD, permissões root |
| Arquivos | Acesso a configs do sistema |
| Rede | Firewall, portas |
| Software | APT, instalação de pacotes |
| Processos | Ver/matar processos |
| Docker | Grupo docker, comandos |
| SSH | Chaves, permissões |
| Ambiente | PATH, /tmp |

**Total**: 25+ testes automatizados

### Testes Manuais Recomendados

```bash
# 1. Sudo funciona sem senha
sudo whoami  # Deve retornar "root" SEM pedir senha

# 2. Docker funciona sem sudo (se instalado)
docker ps  # NÃO deve pedir senha

# 3. Editar arquivo sistema
sudo nano /etc/hosts

# 4. Instalar pacote
sudo apt install htop -y

# 5. Gerenciar serviços
sudo systemctl restart ssh
```

## 🔧 Troubleshooting

### Problema: "Connection refused" na nova porta

**Causa**: ssh.socket bloqueando múltiplas portas

**Solução**:
```bash
sudo systemctl stop ssh.socket
sudo systemctl disable ssh.socket
sudo systemctl restart ssh
```

### Problema: Sudo pede senha

**Causa**: NOPASSWD não configurado

**Solução**:
```bash
# Execute com usuário que tem sudo
sudo ./corrigir_usuario.sh nome-do-usuario
```

### Problema: Docker requer sudo

**Causa**: Usuário não está no grupo docker

**Solução**:
```bash
sudo usermod -aG docker seu-usuario
# LOGOUT e LOGIN novamente
```

### Problema: Esqueci de testar e me tranquei

**Solução**: Use o Console da Oracle Cloud
1. Acesse Oracle Cloud Console
2. Compute → Instances → sua VM
3. Clique em "Console Connection"
4. Crie console connection
5. Acesse via serial console
6. Execute o script de rollback:
```bash
sudo /root/backup_ssh_*/reverter_mudancas.sh
```

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/MinhaFeature`)
3. Commit suas mudanças (`git commit -m 'Adiciona MinhaFeature'`)
4. Push para a branch (`git push origin feature/MinhaFeature`)
5. Abra um Pull Request

### Áreas que precisam de ajuda:

- [ ] Suporte para CentOS/RHEL
- [ ] Suporte para AWS/GCP
- [ ] Integração com Ansible
- [ ] Testes automatizados (CI/CD)
- [ ] Internacionalização (i18n)

## 📊 Roadmap

- [x] Script básico de hardening
- [x] Abordagem em fases
- [x] Sistema de estado
- [x] Testes automatizados
- [x] Bootstrap installer
- [ ] Suporte multi-distro
- [ ] Interface web
- [ ] Integração com Terraform
- [ ] Métricas e monitoring

## 📝 Changelog

### v2.0.0 (2025-10-17)
- ✨ Abordagem incremental em 3 fases
- ✨ Sistema de estado e rollback
- ✨ Script de testes (25+ validações)
- ✨ Bootstrap automático
- ✨ Configuração automática de docker
- 🐛 Corrigido problema com ssh.socket
- 🐛 Corrigido sudo NOPASSWD

### v1.0.0 (2025-10-15)
- 🎉 Release inicial

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 👥 Autores

- **Initial work** - [yesyoudeserve](https://github.com/yesyoudeserve)

## 🙏 Agradecimentos

- Oracle Cloud por fornecer infraestrutura gratuita
- Comunidade open source
- Todos os contribuidores

## ⚠️ Disclaimer

Este toolkit é fornecido "como está", sem garantias. Use por sua própria conta e risco. Sempre faça backups antes de aplicar mudanças de segurança em produção.

---

**⭐ Se este projeto foi útil, considere dar uma estrela no GitHub!**

**🐛 Encontrou um bug?** [Abra uma issue](https://github.com/yesyoudeserve/vm-security/issues)

**❓ Tem dúvidas?** [Consulte as Discussions](https://github.com/yesyoudeserve/vm-security/discussions)