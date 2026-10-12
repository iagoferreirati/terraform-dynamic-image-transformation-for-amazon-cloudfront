# Dynamic Image Transformation com Terraform

Infraestrutura Terraform nativa para servir e otimizar dinamicamente imagens do bucket `certificado-carryontech`. Ela substitui a implantação CloudFormation da solução AWS SO0023, mantendo o artefato oficial do processador de imagens v8.1.1 e gerenciando Lambda, IAM, API Gateway, CloudFront, cache, logs e a função de borda em Terraform.

Veja [a arquitetura](ARCHITECTURE.md) e [todos os parâmetros](PARAMETERS.md).

## Dashboard de economia

O Terraform cria um dashboard CloudWatch com bytes originais, bytes otimizados, bytes economizados, percentual médio de redução, imagens processadas, erros e cache hit rate. Use `terraform output -raw cloudwatch_dashboard` após o apply.

## O que a função de borda resolve

O frontend chama apenas:

```text
https://<dominio-cloudfront>/Fotos_Cybersecfest_2025_DHL_Producoes-479.jpg
```

Antes do cache, a CloudFront Function inclui `format=webp` e `quality=0.82` (configuráveis), preservando as dimensões da imagem. Redimensionamento somente acontece se a URL trouxer `width` ou `height` explicitamente.

## Implantação

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Depois, obtenha o novo endpoint:

```bash
terraform output -raw image_endpoint
```

O domínio padrão do CloudFront é novo em cada recriação. Para preservar URLs entre recriações, configure um domínio próprio, certificado ACM em `us-east-1` e DNS antes do próximo deploy.

O certificado padrão do CloudFront obriga o mínimo TLSv1. Ao configurar um domínio próprio com certificado ACM, altere `minimum_protocol_version` para `TLSv1.2_2021`.

## Limites e segurança

- A URL está pública, como estava na stack original. Para imagens privadas ou proteção contra abuso, acrescente assinatura de URL e WAF antes de expor o domínio ao público.
- O bucket de origem não é apagado pelo Terraform.
- O bucket de access logs usa `force_destroy = true`; `terraform destroy` remove seus logs.
- Os recursos de demonstração, telemetria anônima e custom resources do CDK da solução original não fazem parte desta implementação. Eles não são necessários ao caminho de entrega de imagens e foram removidos em favor de recursos Terraform nativos.
