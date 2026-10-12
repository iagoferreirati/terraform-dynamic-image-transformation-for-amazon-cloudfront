# Parâmetros

Os valores devem ficar em `terraform.tfvars`, criado a partir de `terraform.tfvars.example`. Não versionar segredos nesse arquivo.

| Variável | Padrão | Efeito |
| --- | --- | --- |
| `aws_region` | `us-east-1` | Região de API Gateway, Lambda, logs e bucket de logs. |
| `aws_profile` | `iago-cursos` | Profile AWS CLI usado pelo provider Terraform. |
| `name_prefix` | `dynamic-image-transformation` | Prefixo e identificador dos recursos Terraform. |
| `source_bucket` | `certificado-carryontech` | Bucket existente que contém os originais. Ele não é gerenciado nem excluído. |
| `default_quality` | `0.82` | Qualidade de compressão de 0 a 1, adicionada quando ausente. |
| `default_format` | `webp` | Formato de saída padrão. Pode ser `jpg`, `jpeg`, `png`, `webp`, `avif`, `gif` ou `tiff`. |
| `enable_auto_webp` | `false` | Faz a Lambda considerar o cabeçalho `Accept` para WebP. Normalmente deixe `false` quando `default_format = "webp"`. |
| `enable_cors` | `false` | Habilita CORS para `fetch()` e canvas. Não é necessário para `<img>`. |
| `cors_origin` | `*` | Origem permitida pelo CORS. Use o domínio real do frontend quando CORS estiver habilitado. |
| `cloudfront_price_class` | `PriceClass_All` | Cobertura de borda do CloudFront. `100` e `200` reduzem custo e também cobertura. |
| `log_retention_days` | `30` | Retenção dos logs da Lambda no CloudWatch. |
| `log_expiration_days` | `90` | Expiração dos access logs do CloudFront no S3. |

## Parâmetros opcionais de URL

O frontend não precisa enviar parâmetros. A CloudFront Function adiciona `format` e `quality` aos URLs limpos, preservando as dimensões originais.

Caso seja necessário sobrescrever um caso específico, os parâmetros explícitos têm prioridade:

```text
https://<dominio-cloudfront>/pasta/foto.jpg?width=480&format=webp&quality=0.75
```

Parâmetros úteis suportados pela Lambda: `width`, `height`, `fit` (`cover`, `contain`, `fill`, `inside`, `outside`), `format`, `quality`, `rotate`, `flip`, `flop` e `greyscale`.

## Uso no frontend

Após `terraform apply`, use o valor de `image_endpoint`:

```jsx
<img src={`${IMAGE_ENDPOINT}/Fotos_Cybersecfest_2025_DHL_Producoes-479.jpg`} alt="Evento" />
```

Não inclua `s3:certificado-carryontech` no caminho: há apenas um bucket de origem e a Lambda usa-o como padrão.
