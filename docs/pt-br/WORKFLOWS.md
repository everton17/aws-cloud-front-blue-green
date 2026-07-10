# 🤖 Guia de Workflows do GitHub Actions

Este guia explica como os workflows do GitHub Actions são auto-gerados e seu papel na stack de deployment.

---

## 📋 Referência Rápida

| Workflow | Modality | Propósito | Trigger |
|----------|----------|-----------|---------|
| `deploy.yml` | Todas | Build, upload, invalidar cache | Push para main |
| `rollback.yml` | Rollback, Versionamento | Toggle SSM, invalidar cache | Manual |
| `rollback-and-restore.yml` | Versionamento | Restaurar versão específica | Manual + SHA |

---

## Como Workflows São Gerados

### O Processo de Geração

1. **Você configura `workflow_option` em terraform.tfvars:**
   ```hcl
   gha_gen_workflows = {
     workflow_option = "simple-deploy"  # ou "deploy-and-rollback" ou "deploy-rollback-and-restore"
   }
   ```

2. **O módulo Terraform `gha_gen_workflows` lê sua escolha:**
   - Seleciona quais workflows gerar
   - Cria papéis IAM e relações de confiança OIDC
   - Gera arquivos YAML de workflow

3. **Arquivos são criados em `.github/workflows/`:**
   ```
   .github/workflows/
   ├── deploy.yml (sempre gerado)
   ├── rollback.yml (se modality rollback)
   └── rollback-and-restore.yml (se modality versionamento)
   ```

4. **Você faz commit e push:**
   ```bash
   git add .github/workflows/
   git commit -m "ci: add generated deployment workflows"
   git push origin main
   ```

### Workflows por Modality

| `workflow_option` | Modality | Workflows Gerados |
|-------------------|----------|------------------|
| `simple-deploy` | Simples | • `deploy.yml` |
| `deploy-and-rollback` | Rollback | • `deploy.yml`<br>• `rollback.yml` |
| `deploy-rollback-and-restore` | Versionamento | • `deploy.yml`<br>• `rollback-and-restore.yml` |

---

## 🚀 deploy.yml

**Quando é gerado:** Sempre (todas as modalities)

### O que faz:
1. Build da sua app (`npm run build`)
2. Upload para bucket S3 de produção
3. Copia versão anterior para bucket de rollback (se Rollback/Versionamento)
4. Arquiva versão (se Versionamento)
5. Invalida cache do CloudFront
6. Reseta parâmetro SSM para `false` (se Rollback/Versionamento)

### Trigger:
```bash
# Automático: Push para main
git push origin main

# Manual: Rodar workflow
gh workflow run deploy.yml
```

### Autenticação:
Usa OIDC (sem chaves AWS de longa duração). Relação de confiança GitHub → AWS configurada por Terraform.

### Timing:
~2-3 minutos por deploy

---

## 🔄 rollback.yml

**Quando é gerado:** Apenas modalities Rollback e Versionamento

### O que faz:
1. Toggle parâmetro SSM de `false` → `true`
2. Invalida cache do CloudFront
3. Lambda@Edge detecta toggle dentro de ~60 segundos
4. Tráfego muda para bucket de rollback (azul)

### Trigger:
```bash
# Manual: Rodar workflow de rollback
gh workflow run rollback.yml

# Ou: GitHub Actions UI → rollback.yml → Run workflow
```

### Resultado:
Versão anterior fica live instantaneamente. Sem rebuild, sem re-upload.

### Timing:
~30 segundos

---

## 🔌 rollback-and-restore.yml

**Quando é gerado:** Apenas modality Versionamento

### O que faz:
1. Aceita SHA de versão como parâmetro de entrada
2. Baixa arquivo do bucket S3 de versões
3. Extrai e faz upload para bucket de produção
4. Toggle SSM se necessário
5. Invalida cache do CloudFront

### Trigger:
```bash
# Obter versões disponíveis
aws s3 ls s3://demo-site-versions-*/

# Restaurar versão específica por SHA
gh workflow run rollback-and-restore.yml \
  -f version_sha=abc123def456

# Ou: GitHub Actions UI → rollback-and-restore.yml → input SHA
```

### Exemplo:
```bash
# Se quiser restaurar versão do commit abc123
gh workflow run rollback-and-restore.yml -f version_sha=abc123
# Workflow baixa version-abc123.tar.gz, extrai, faz upload para produção
```

### Timing:
~1-2 minutos

---

## ⚠️ Importante: Não Edite Workflows Manualmente

**Workflows são regerados cada vez que você roda `terraform apply`.**

```bash
terraform apply -var-file=terraform.tfvars
# Isto SOBRESCREVE .github/workflows/ com versões regeradas
```

### Estratégia de Customização

Se precisar customizar um workflow:

1. **Edite o template** em `modules/gha_gen_workflows/templates/`
2. **Não edite** os arquivos gerados `.github/workflows/*.yml`
3. **Rode terraform apply** para regenerar com suas mudanças

Veja [gha_gen_workflows README](../../modules/gha_gen_workflows/README.md) para detalhes de templates.

---

## 🔐 Autenticação e Permissões

Todos os workflows usam **OIDC (OpenID Connect)** para autenticação AWS:

- ✅ **Sem chaves AWS de longa duração** armazenadas no GitHub
- ✅ **Papel IAM de menor privilégio** por modality
- ✅ **Geração automática de token** por execução de workflow
- ✅ **Escopo para recursos AWS específicos** (buckets, CloudFront, SSM)

Configurado automaticamente pelo módulo `gha_gen_workflows`.

---

## Fluxo de Execução de Workflow

```
┌─────────────────┐
│   Evento Git    │
├─────────────────┤
│ Push para main  │
│ OU trigger      │
│ manual          │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Job GitHub Actions Inicia      │
├─────────────────────────────────┤
│ 1. Assumir papel IAM via OIDC   │
│ 2. Build da aplicação           │
│ 3. Upload para AWS (S3/SSM)     │
│ 4. Invalidar cache CloudFront   │
└────────┬────────────────────────┘
         │
         ▼
    ✅ Sucesso
    (Lambda@Edge aplica mudanças dentro de ~60s)
```

---

## Troubleshooting

### Workflow não inicia após push
- Verifique branch: workflows apenas triggeram em `main` (padrão)
- Mude: edite `gha_gen_workflows.deploy_branch` em terraform.tfvars

### Falha de autenticação OIDC
- Verifique se papel IAM existe: `aws iam get-role --role-name github-actions-deploy`
- Verifique relação de confiança no console AWS

### Rollback não funciona
- Verifique parâmetro SSM: `aws ssm get-parameter --name /Lambda/CF/Rollback`
- Aguarde 60s: TTL do cache do Lambda@Edge
- Verifique status de invalidação do CloudFront

### Mudanças de Lambda@Edge não visíveis
- Lambda@Edge leva 5-10 minutos para replicar globalmente
- Isto é comportamento normal da AWS

---

## Exemplos

### Execução simples de workflow (Deploy)
```bash
# Automático em push
git push origin main

# Ou manual
gh workflow run deploy.yml

# Verificar status
gh run list --workflow deploy.yml
```

### Exemplo de rollback
```bash
# Algo quebrou em produção...
gh workflow run rollback.yml

# Tráfego muda para versão anterior instantaneamente
# Usuários não veem nenhum downtime
```

### Exemplo de restauração de versão específica
```bash
# Você quer voltar para commit abc123
gh workflow run rollback-and-restore.yml -f version_sha=abc123

# Workflow restaura aquela versão exata
```

---

## Documentação Relacionada

- [Guia de DEMO](./DEMO.md) - Como testar workflows
- [Configuração Completa](./full-guide.md) - Todas as opções de variáveis
- [Módulo gha_gen_workflows](../../modules/gha_gen_workflows/README.md) - Internals do módulo
