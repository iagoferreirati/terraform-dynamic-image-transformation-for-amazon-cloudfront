output "image_endpoint" {
  description = "Use this domain in the frontend in place of the direct S3 domain. Default transformations are injected automatically."
  value       = "https://${aws_cloudfront_distribution.image.domain_name}"
}

output "image_url_example" {
  description = "A clean image URL: callers do not need to supply width, format, or quality."
  value       = "https://${aws_cloudfront_distribution.image.domain_name}/Fotos_Cybersecfest_2025_DHL_Producoes-479.jpg"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.image.id
}

output "source_bucket" {
  value = var.source_bucket
}

output "cloudwatch_dashboard" {
  description = "CloudWatch dashboard with transformation savings and CloudFront cache metrics."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.image_optimization.dashboard_name}"
}
