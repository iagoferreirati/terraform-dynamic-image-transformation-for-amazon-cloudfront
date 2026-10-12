resource "aws_cloudwatch_dashboard" "image_optimization" {
  dashboard_name = "${local.name}-optimization"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Bytes originais vs. otimizados"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
          metrics = [
            [local.metrics_namespace, "OriginalBytes", "Service", local.name, { label = "Originais" }],
            [".", "OptimizedBytes", ".", ".", { label = "Entregues" }],
            [".", "SavedBytes", ".", ".", { label = "Economizados" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Redução média por transformação"
          region = var.aws_region
          view   = "singleValue"
          stat   = "Average"
          period = 300
          metrics = [
            [local.metrics_namespace, "SavedPercent", "Service", local.name, { label = "Redução média (%)" }],
            [local.metrics_namespace, "ProcessedImages", "Service", local.name, { label = "Imagens processadas", stat = "Sum" }],
            [local.metrics_namespace, "ProcessingErrors", "Service", local.name, { label = "Erros", stat = "Sum" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Cache hit rate do CloudFront"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/CloudFront", "CacheHitRate", "DistributionId", aws_cloudfront_distribution.image.id, "Region", "Global"],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Invocações e erros da telemetria"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.metrics_wrapper.function_name],
            [".", "Errors", ".", "."],
          ]
        }
      },
    ]
  })
}
