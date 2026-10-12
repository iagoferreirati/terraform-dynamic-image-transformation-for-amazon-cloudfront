# Arquitetura

```mermaid
flowchart LR
    Browser[Frontend / navegador] -->|URL limpa: /pasta/foto.jpg| CF[CloudFront]
    CF --> Edge[CloudFront Function\ninjeta format e quality]
    Edge --> Cache{Cache\npath + parâmetros}
    Cache -->|miss| API[API Gateway /image]
    API --> Metrics[Lambda de telemetria]
    Metrics -->|HeadObject| Source[(S3\ncertificado-carryontech)]
    Metrics --> Lambda[Lambda\nAWS Solutions SO0023 v8.1.1]
    Lambda -->|GetObject| Source
    Lambda -->|imagem WebP otimizada| Metrics
    Metrics -->|imagem WebP otimizada| API
    API --> CF
    CF --> Browser
    CF -. access logs .-> Logs[(S3 logs)]
    Lambda -. logs .-> CW[CloudWatch Logs]
    Metrics -. métricas EMF .-> CW
```

## Fluxo

1. O frontend pede somente o caminho da imagem usando o domínio retornado por `terraform output image_endpoint`.
2. A CloudFront Function adiciona os padrões configurados (`format` e `quality`) sem alterar as dimensões antes da busca no cache.
3. Em cache miss, CloudFront chama o API Gateway, que aciona a Lambda de telemetria.
4. A telemetria obtém o tamanho original no S3, chama a Lambda de transformação e publica `OriginalBytes`, `OptimizedBytes`, `SavedBytes` e `SavedPercent` via Embedded Metric Format.
5. A resposta fica em cache por caminho e parâmetros.

O bucket de origem é externo ao Terraform e não é removido por `terraform destroy`.
