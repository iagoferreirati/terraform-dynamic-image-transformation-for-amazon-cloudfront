variable "aws_region" {
  description = "AWS region for the API, Lambda, and S3 resources. CloudFront remains global."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile used by Terraform."
  type        = string
  default     = "iago-cursos"
}

variable "name_prefix" {
  description = "Prefix used to name Terraform-managed resources."
  type        = string
  default     = "dynamic-image-transformation"
}

variable "source_bucket" {
  description = "Existing S3 bucket containing the original images. Terraform does not create or delete it."
  type        = string
  default     = "certificado-carryontech"
}

variable "default_quality" {
  description = "Sharp output quality from 0 to 1, injected when absent from the request."
  type        = number
  default     = 0.82

  validation {
    condition     = var.default_quality >= 0 && var.default_quality <= 1
    error_message = "default_quality must be between 0 and 1."
  }
}

variable "default_format" {
  description = "Output format injected when absent."
  type        = string
  default     = "webp"

  validation {
    condition     = contains(["jpg", "jpeg", "png", "webp", "avif", "gif", "tiff"], var.default_format)
    error_message = "default_format must be a supported output format."
  }
}

variable "enable_auto_webp" {
  description = "Enable WebP selection from the browser Accept header in the Lambda handler."
  type        = bool
  default     = false
}

variable "enable_cors" {
  description = "Return CORS headers from the image API. Required for fetch() or canvas usage, but not for img tags."
  type        = bool
  default     = false
}

variable "cors_origin" {
  description = "Allowed origin when enable_cors is true. Prefer a concrete frontend origin over *."
  type        = string
  default     = "*"
}

variable "cloudfront_price_class" {
  description = "CloudFront edge-location coverage and cost tier."
  type        = string
  default     = "PriceClass_All"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.cloudfront_price_class)
    error_message = "cloudfront_price_class must be PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "log_retention_days" {
  description = "CloudWatch retention period for the image-handler Lambda log group."
  type        = number
  default     = 30
}

variable "log_expiration_days" {
  description = "Number of days CloudFront access logs remain in the log bucket."
  type        = number
  default     = 90
}
