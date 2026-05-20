# Terraform provider
provider "aws" {
    region = "us-east-2"
}

# resources

# S3 bucket to store the static website content
resource "aws_s3_bucket" "nextjs_bucket" {
    bucket = "nextjs-portfolio-grk-june-2026"
}

# bucket ownership control - we want 
# total ownership of the objects in the bucket
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls
resource "aws_s3_bucket_ownership_controls" "nextjs_bucket_ownership_controls" {
    bucket = aws_s3_bucket.nextjs_bucket.id
    rule {
        object_ownership = "BucketOwnerPreferred" # bucketowner has control over all objects in bucket even if uploaded by others
    }
}

# remove public access blocking
resource "aws_s3_bucket_public_access_block" "nextjs_bucket_public_access_block" {
    bucket = aws_s3_bucket.nextjs_bucket.id

    block_public_acls = false
    block_public_policy = false
    ignore_public_acls = false
    restrict_public_buckets = false
}

# bucket ACL 
resource "aws_s3_bucket_acl" "nextjs_bucket_acl" {
    depends_on = [ 
        aws_s3_bucket_ownership_controls.nextjs_bucket_ownership_controls, 
        aws_s3_bucket_public_access_block.nextjs_bucket_public_access_block 
    ]
    bucket = aws_s3_bucket.nextjs_bucket.id
    acl = "public-read"
}

# bucket policy to allow public read access to the objects in the bucket
resource "aws_s3_bucket_policy" "nextjs_bucket_policy" {
    bucket = aws_s3_bucket.nextjs_bucket.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid = "PublicReadGetObject"
                Effect = "Allow"
                Principal = "*"
                Action = "s3:GetObject"
                Resource = "${aws_s3_bucket.nextjs_bucket.arn}/*"
            }
        ]
    })
}

# CDN distribution for the S3 bucket
# Origin access identity to restrict access to the S3 bucket only from the CDN
resource "aws_cloudfront_origin_access_identity" "nextjs_origin_access_identity" {
    comment = "OAI for Next.js portfolio website"
}

# CloudFront distribution- set it up to work with the S3 bucket as the origin and use the OAI to restrict access to the bucket
resource "aws_cloudfront_distribution" "nextjs_distribution" {
    origin {
        domain_name = aws_s3_bucket.nextjs_bucket.bucket_regional_domain_name
        origin_id = "S3-nextjs-portfolio-bucket"
        s3_origin_config {
            origin_access_identity = aws_cloudfront_origin_access_identity.nextjs_origin_access_identity.cloudfront_access_identity_path
        }
    }

    enabled = true
    is_ipv6_enabled = true # enable IPv6 support for the distribution
    comment = "next.js portfolio site"
    default_root_object = "index.html"

    default_cache_behavior {
        target_origin_id = "S3-nextjs-portfolio-bucket"
        viewer_protocol_policy = "redirect-to-https"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
        allowed_methods = ["GET", "HEAD", "OPTIONS"]
        cached_methods = ["GET", "HEAD"]
        
        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }

}