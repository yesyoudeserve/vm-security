# ⚡ Guia Rápido - VM Security

Referência rápida para uso diário do toolkit.
Version: 2.0.0

## 🚀 Instalação (1 linha)

```bash
curl -sSL https://raw.githubusercontent.com/yesyoudeserve/vm-security/main/bootstrap.sh | bash
```

## 📋 Fluxo Completo

### 1️⃣ Pré-requisito: Oracle Cloud Security List

```
Oracle Cloud Console → Networking → VCN → Security Lists
→ Add Ingress Rule → TCP → Porta: SUA_PORTA_ESCOLHIDA
```

### 2️⃣ Fase 1: Nova Porta

```bash
cd ~/vm-security
sudo ./ssh_hardening.sh --fase1
# Digite a porta (ex: 49100)
```

**Teste:**
```bash
# Em outro terminal
ssh -i sua-chave.pem -p 49100 usuario@ip
```

### 3️⃣ Fase 2: Novo Usuário

```bash
sudo ./ssh_hardening.sh --fase2
# Digite nome do usuário (ex: admin)
```

**Teste:**
```bash
ssh -i sua-chave.pem -p 49100 admin@ip
./teste_usuario.sh
```

### 4️⃣ Fase 3: Finalizar

```bash
sudo ./ssh_hardening.sh --fase3
# Confirme com "CONFIRMO"
```

**Pós-fase 3:**
- ✅ Remover porta 22 do Security List
- ✅ Testar acesso final

## 🧪 Comandos de Teste

```bash
# Teste sudo (não deve pedir senha)
sudo whoami

# Teste docker
docker ps

# Teste completo (25+ validações)
./teste_usuario.sh

# Ver estado atual
sudo ./ssh_hardening.sh
```

## 🔧 Correções Rápidas

### Sudo pede senha

```bash
sudo ./corrigir_usuario.sh nome-usuario
```

### Docker requer sudo

```bash
sudo usermod -aG docker nome-usuario
# Logout e login novamente
```

### SSH socket problem

```bash
sudo systemctl stop ssh.socket
sudo systemctl disable ssh.socket
sudo systemctl restart ssh
```

## 📊 Checklist de Segurança

- [ ] Porta SSH customizada ativa
- [ ] Novo usuário criado e testado
- [ ] Teste de privilégios: 100% aprovado
- [ ] Porta 22 removida do SSH
- [ ] Porta 22 removida do Security List
- [ ] Login por senha desabilitado
- [ ] Login root desabilitado
- [ ] Backup salvo em `/root/backup_ssh_*`

## 🆘 Emergência: Reverter Tudo

```bash
# Via SSH (se ainda tiver acesso)
sudo /root/backup_ssh_*/reverter_mudancas.sh

# Via Serial Console (se perdeu acesso SSH)
# 1. Oracle Console → Compute → Instance → Console Connection
# 2. Execute o comando acima
```

## 📁 Arquivos Importantes

```
~/vm-security/
├── ssh_hardening.sh       # Script principal
├── teste_usuario.sh       # Testes de validação
├── corrigir_usuario.sh    # Correção rápida
└── README.md              # Documentação completa

/root/
├── .ssh_hardening_estado  # Estado do progresso
└── backup_ssh_*/          # Backups automáticos
```

## 🔍 Verificar Configuração Atual

```bash
# Ver portas SSH ativas
sudo ss -tulnp | grep sshd

# Ver config SSH atual
sudo sshd -T | grep -E "port|password|root|pubkey"

# Ver estado do hardening
cat /root/.ssh_hardening_estado

# Ver usuários com sudo
getent group sudo

# Ver firewall
sudo ufw status
sudo iptables -L INPUT -n
```

## 💡 Dicas

### Conectar após hardening

```bash
# Sempre use a nova porta
ssh -i ~/.ssh/sua-chave.pem -p PORTA usuario@ip

# Ou configure ~/.ssh/config
cat >> ~/.ssh/config << EOF
Host minha-vm
    HostName SEU_IP
    Port PORTA
    User USUARIO
    IdentityFile ~/.ssh/sua-chave.pem
EOF

# Depois: ssh minha-vm
```

### Adicionar nova chave SSH

```bash
# No novo usuário
echo "ssh-rsa AAAA..." >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Ver logs de acesso

```bash
sudo tail -f /var/log/auth.log
# ou
sudo journalctl -u ssh -f
```

## ⚙️ Variáveis de Ambiente Úteis

```bash
# Localização dos scripts
INSTALL_DIR="$HOME/vm-security"

# Arquivo de estado
ESTADO="/root/.ssh_hardening_estado"

# Diretório de backup
BACKUP_DIR="/root