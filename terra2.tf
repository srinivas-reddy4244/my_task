provider "aws" {
 region  = "ap-south-1"
 profile = "srinivas"
}




resource "tls_private_key" "task_key1" {
 algorithm = "RSA"
}


resource "aws_key_pair" "generated_key" {
 key_name    = "task_key1"
 public_key  = tls_private_key.task_key1.public_key_openssh

 depends_on = [
  tls_private_key.task_key1
 ]
}

resource "local_file" "taskkey1-file" {
 content  = tls_private_key.task_key1.private_key_pem
 filename = "task_key1.pem"

 depends_on = [
  tls_private_key.task_key1
 ]
}


resource "aws_security_group" "my_security2" {
  name        = "my_security2"
  description = "Allow inbound traffic"
 

  ingress {
    description = "allow_my_clients of HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow_my_clients of SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_my_client"

  }
}

resource "aws_instance" "task_instance" {


 ami            ="ami-0732b62d310b80e97"
 instance_type  ="t2.micro"
 key_name       = aws_key_pair.generated_key.key_name
 security_groups = ["my_security2"]

connection {
     type = "ssh"
     user = "ec2-user"
     private_key = tls_private_key.task_key1.private_key_pem
     host   = aws_instance.task_instance.public_ip
 }

provisioner "remote-exec" {
    inline = [
        "sudo yum install httpd php git -y",
         "sudo yum install git -y",
        "sudo systemctl  restart httpd",
        "sudo systemctl enable httpd", 
      ]
     }
    tags = {
     Name = "taskinstance"
   }
 }


resource "aws_ebs_volume" "my_volume" {
 availability_zone = aws_instance.task_instance.availability_zone
 size              = 1
tags = {
  Name = "ebs_volume1"
 }
}

resource "aws_volume_attachment" "volume_att" {
 device_name  = "/dev/sdh"
 volume_id    = aws_ebs_volume.my_volume.id
 instance_id  = aws_instance.task_instance.id
 force_detach = true
}

resource "null_resource" "nullremote1" {
 depends_on = [
  aws_volume_attachment.volume_att
 ]
connection {
  type        = "ssh"
  user        = "ec2-user"
  private_key = tls_private_key.task_key1.private_key_pem
  host        = aws_instance.task_instance.public_ip
 }
provisioner "remote-exec" {
  inline = [
   "sudo mkfs.ext4 /dev/xvdh",
   "sudo mount /dev/xvdh /var/www/html",
   "sudo rm -rf /var/www/html/*",
   "sudo git clone https://github.com/srinivas-reddy4244/my_task.git /var/www/html"
        ]
    }
}
 

resource "null_resource" "nulllocal31" {
  depends_on = [
      null_resource.nullremote1,
    ]
provisioner "local-exec" {
   command = "git clone https://github.com/srinivas-reddy4244/my_task.git  C:/Users/sathish reddy/Desktop/task2/repo/"
   when = destroy
  } 
}

resource "aws_s3_bucket" "task1bucket-buck" {
depends_on = [
    null_resource.nulllocal31,    
  ]     
  bucket = "task1bucket-buck"
  force_destroy = true
  acl    = "public-read"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::task1bucket-buck/*"
    }
  ]
}
POLICY
        }  

resource "aws_s3_bucket_object" "object" {
  depends_on = [ aws_s3_bucket.task1bucket-buck,
                null_resource.nullremote1,
                null_resource.nulllocal31,
 ]
     bucket = aws_s3_bucket.task1bucket-buck.id
  key    = "one"
  source = "C:/Users/sathish reddy/Desktop/task2/img/srinivas.jpg"
  etag = "C:/Users/sathish reddy/Desktop/task2/img/srinivas.jpg"
  acl = "public-read"
  content_type = "image/jpg"
}


locals {
   s3_origin_id = "myS3Origin"
}
resource "aws_cloudfront_origin_access_identity" "oai" {
   comment = "CloudFront S3 sync"
}
resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [
    aws_key_pair.generated_key,
    aws_instance.task_instance
  ] 
  origin {
    domain_name = aws_s3_bucket.task1bucket-buck.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "ClouFront S3 sync"
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
# Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
      query_string = false
      headers      = ["Origin"]
      cookies {
        forward = "none"
      }
    }
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }
# Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }
  price_class = "PriceClass_200"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  tags = {
    Environment = "production"
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "null_resource" "nullremote2" {
 depends_on = [ aws_cloudfront_distribution.s3_distribution, ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task_key1.private_key_pem
    host     = aws_instance.task_instance.public_ip
   }
   provisioner "remote-exec" {
      inline = [
      "sudo su << EOF",
      "echo \"<img src='https://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.object.key }'>\" >> /var/www/html/index.html",
       "EOF"
   ]
 }
}

resource "null_resource" "nulllocal3" {
  depends_on = [
      null_resource.nullremote2,
   ]
   provisioner "local-exec" {
         command = "start chrome ${aws_instance.task_instance.public_ip}/index.html"
    }
}
  
output "myos_ip" {
  value = aws_instance.task_instance.public_ip
}
output "private_key" {
  value = tls_private_key.task_key1.private_key_pem
}
