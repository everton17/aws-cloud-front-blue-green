# 🚀 CloudFront Blue-Green Stack - Guia de Demo

Este guia percorre demostrações rápidas dos três stacks de deployment usando arquivos tfvars pré-configurados.

---

## 📋 Referência Rápida

| Demo | Arquivo | Tempo | Funcionalidades |
|------|---------|-------|-----------------|
| **Simples** | `terraform-simple-demo.tfvars` | 5 min | CloudFront + S3 |
| **Rollback** | `terraform-rollback-demo.tfvars` | 8 min | + Lambda@Edge + Blue/Green |
| **Versionamento** | `terraform-versioning-demo.tfvars` | 10 min | + Arquivo de Versões + Restaurar |

---

## 🛣️ Dois Caminhos: Manual vs Workflows GitHub Actions

Cada demo pode ser testada de **duas formas**:

| Caminho | Método | Quando Usar | Tempo |
|--------|--------|------------|-------|
| **Manual** | AWS CLI (`aws s3 cp`, `aws ssm put-parameter`, etc.) | Aprendizado, debug, testes rápidos | ~5-10 min |
| **Workflows** ⭐ | GitHub Actions (auto-gerado pelo Terraform) | Testes em produção, validação CI/CD, **recomendado** | ~3-5 min por workflow |

**Recomendado:** Use **workflows GitHub Actions** — demonstra a stack funcionando end-to-end com autenticação OIDC, exatamente como estará em produção.

---

## 🟢 DEMO 1: Stack Simples (5 minutos)

**O que você verá:** Deployment básico de CloudFront + S3  
**Perfeito para:** Entender os fundamentos

### Setup e Deploy

```bash
# Planejar a infraestrutura
terraform plan -var-file=terraform-simple-demo.tfvars -out=simple.plan

# Aplicar
terraform apply simple.plan

# Deploy da app de demo
cd bluegreen_site && npm run build
aws s3 cp dist/ s3://demo-site-production-*/ --recursive --profile default

# Testar
DOMAIN=$(terraform output -raw cloudfront_distribution_domain)
curl -I https://$DOMAIN/
```

### O que Mostrar

- ✅ Distribuição CloudFront criada
- ✅ Bucket S3 com OAC (acesso privado)
- ✅ Respostas de erro customizadas (404 → index.html para SPA)
- ✅ Comportamentos de cache (caminhos de API com TTL diferente)

### ⭐ Usando Workflows GitHub Actions (Recomendado)

Em vez de comandos manuais de AWS CLI, use o workflow auto-gerado:

```bash
# 1. Fazer commit do workflow gerado
git add .github/workflows/deploy.yml
git commit -m "ci: add auto-generated deployment workflow"
git push origin main

# 2. Triggerar o workflow (automático em push ou manual)
gh workflow run deploy.yml

# 3. Monitorar o workflow
gh run list --workflow deploy.yml
gh run view [RUN_ID]  # Ver logs e outputs
```

**Resultado:** Mesmo deployment, mas com autenticação OIDC e validação CI/CD completa — exatamente como funcionará em produção.

---

## 🔵 DEMO 2: Blue-Green Rollback (8 minutos)

**O que você verá:** Capacidade de rollback instantâneo  
**Perfeito para:** Mostrar deploys sem downtime

### Setup e Deploy

```bash
# Planejar e aplicar stack com rollback
terraform plan -var-file=terraform-rollback-demo.tfvars -out=rollback.plan
terraform apply rollback.plan

# Deploy versão 1
cd bluegreen_site && npm run build
aws s3 cp dist/ s3://demo-site-green-*/ --recursive

# Obter domínio
DOMAIN=$(terraform output -raw cloudfront_distribution_domain)
curl https://$DOMAIN/ | grep VERSION

# Deploy versão 2 (preparar para rollback)
echo "<h1>VERSÃO 2 - LIVE!</h1>" > src/index.html
npm run build
aws s3 cp dist/ s3://demo-site-green-*/ --recursive

# Copiar v1 para bucket de rollback
aws s3 cp dist-old/ s3://demo-site-blue-*/ --recursive
```

### ✨ Rollback Instantâneo

```bash
# Toggle para versão anterior
aws ssm put-parameter --name "/BlueGreen/Rollback" --value "true" --overwrite

# Aguardar ~60 segundos para TTL do cache do Lambda
sleep 60

# Verificar rollback (agora servindo versão 1)
curl https://$DOMAIN/ | grep VERSION
# Mostra "VERSÃO 1" - ROLLBACK INSTANTÂNEO! 🎉

# Toggle de volta
aws ssm put-parameter --name "/BlueGreen/Rollback" --value "false" --overwrite
```

### Pontos-Chave

> "Este é deployment sem downtime. Em vez de rebuildar no rollback, alternamos um parâmetro SSM que Lambda@Edge lê. A mudança é instantânea e a versão anterior já está aquecida no bucket azul."

### ⭐ Usando Workflows GitHub Actions (Recomendado)

Use os workflows auto-gerados para o fluxo completo de produção:

```bash
# 1. Deploy com o workflow de deploy
gh workflow run deploy.yml
gh run watch  # Aguardar conclusão

# 2. Rollback com um comando
gh workflow run rollback.yml

# 3. Monitorar ambos
gh run list --limit 10
```

**Resultado:** Ciclo blue-green completo com autenticação OIDC, igual ao deployment em produção.

---

## 📦 DEMO 3: Versionamento com Arquivo (10 minutos)

**O que você verá:** Histórico completo de versões + restaurar qualquer versão  
**Perfeito para:** Mostrar recuperação de desastres de nível empresarial

### Setup e Deploy

```bash
# Planejar e aplicar stack com versionamento
terraform plan -var-file=terraform-versioning-demo.tfvars -out=versioning.plan
terraform apply versioning.plan

# Deploy versão 1
cd bluegreen_site && npm run build
COMMIT_V1=$(git rev-parse --short HEAD)

# Arquivar versão 1
tar -czf /tmp/version-$COMMIT_V1.tar.gz dist/
aws s3 cp /tmp/version-$COMMIT_V1.tar.gz s3://demo-site-versions-*/

# Deploy para produção
aws s3 cp dist/ s3://demo-site-production-*/ --recursive
DOMAIN=$(terraform output -raw cloudfront_distribution_domain)
curl https://$DOMAIN/

# Deploy versão 2
echo "<h1>VERSÃO 2</h1>" > src/index.html
npm run build
COMMIT_V2=$(git rev-parse --short HEAD)

# Arquivar e fazer deploy v2
tar -czf /tmp/version-$COMMIT_V2.tar.gz dist/
aws s3 cp /tmp/version-$COMMIT_V2.tar.gz s3://demo-site-versions-*/
aws s3 cp dist/ s3://demo-site-production-*/ --recursive
```

### Rollback e Restaurar

```bash
# Rollback instantâneo para v1
aws ssm put-parameter --name "/Versioning/Rollback" --value "true" --overwrite
sleep 60
curl https://$DOMAIN/ | grep VERSION  # Mostra v1

# Restaurar versão específica (v2)
aws s3 cp s3://demo-site-versions-*/version-$COMMIT_V2.tar.gz /tmp/
tar -xzf /tmp/version-$COMMIT_V2.tar.gz
aws s3 cp dist/ s3://demo-site-production-*/ --recursive
aws ssm put-parameter --name "/Versioning/Rollback" --value "false" --overwrite

# Listar versões disponíveis
aws s3 ls s3://demo-site-versions-*/
```

### Pontos-Chave

> "Deployment de nível produção: faça rollback instantaneamente E restaure qualquer versão histórica do arquivo completo. Cada build é arquivado com seu SHA de commit, então você sempre tem um backup."

### ⭐ Usando Workflows GitHub Actions (Recomendado)

Use os três workflows para o fluxo de produção completo:

```bash
# 1. Deploy com o workflow de deploy (auto-arquiva)
gh workflow run deploy.yml
gh run watch

# 2. Rollback instantâneo
gh workflow run rollback.yml

# 3. Restaurar uma versão específica
gh workflow run rollback-and-restore.yml -f version_sha=abc123def456

# 4. Monitorar todos os runs
gh run list --limit 10
```

**Resultado:** Ciclo de versionamento completo com arquivamento automático, autenticação OIDC e recuperação de desastres — pronto para produção.

---

## 🎯 Sequência Completa de Demo (30 minutos)

Execute as três demos uma após a outra para mostrar a progressão:

```bash
# Demo 1: Simples (5 min)
terraform apply -var-file=terraform-simple-demo.tfvars -auto-approve
# ... seguir fluxo Demo 1 ...
terraform destroy -var-file=terraform-simple-demo.tfvars -auto-approve

# Demo 2: Rollback (8 min)
terraform apply -var-file=terraform-rollback-demo.tfvars -auto-approve
# ... seguir fluxo Demo 2 ...
terraform destroy -var-file=terraform-rollback-demo.tfvars -auto-approve

# Demo 3: Versionamento (10 min)
terraform apply -var-file=terraform-versioning-demo.tfvars -auto-approve
# ... seguir fluxo Demo 3 ...
terraform destroy -var-file=terraform-versioning-demo.tfvars -auto-approve
```

---

## 💡 Dicas

- **Mostre o AWS Console:** Abra CloudFront, S3, Lambda, SSM em abas de navegador
- **Cronométre o rollback:** Mostre a mudança instantânea (< 60s)
- **Lambda@Edge:** Normal levar 5-10 minutos para replicar globalmente
- **Consistência S3:** Use `--region us-east-1` explicitamente se necessário

---

## ✅ Checklist de Demo

- [ ] **AWS CLI instalado** — [Instalar](https://aws.amazon.com/pt/cli/)
- [ ] **Credenciais AWS configuradas:**
  ```bash
  # Opção 1: Via AWS CLI
  aws configure
  
  # Opção 2: Via variáveis de ambiente
  export AWS_ACCESS_KEY_ID=sua-access-key
  export AWS_SECRET_ACCESS_KEY=sua-secret-key
  export AWS_DEFAULT_REGION=us-east-1
  
  # Validar
  aws sts get-caller-identity
  ```
- [ ] Token GitHub configurado (se testar workflows)
- [ ] `terraform init` concluído
- [ ] Dependências bluegreen_site instaladas (`npm install`)
- [ ] Domínio CloudFront anotado

---

## 📊 Limpeza e Custo

Após as demos, remova todos os recursos:

```bash
for config in terraform-simple-demo.tfvars terraform-rollback-demo.tfvars terraform-versioning-demo.tfvars; do
  terraform destroy -var-file=$config -auto-approve 2>/dev/null || true
done
```

**Custo por demo de 10 minutos:** ~$0,10-0,62 (depende do uso de Lambda@Edge)

---

## 🎓 Resultados de Aprendizado

Após executar essas três demos, você entenderá: deployment básico do CloudFront (Simples), deploys sem downtime com rollback instantâneo (Rollback), e histórico completo de versões com recuperação de desastres (Versionamento).

---

**Veja também:** [Guia de Workflows](./WORKFLOWS.md) | [Guia de Configuração Completa](./full-guide.md)
