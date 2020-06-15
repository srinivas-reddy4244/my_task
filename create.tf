provider "aws" {
 region  = "ap-south-1"
 profile = "terraform1"
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
  vpc_id      = "vpc-996d71f1"

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




resource "aws_instance" "final_task_instance" {

 depends_on = [
               aws_security_group.my_security2
                   ]

 ami            ="ami-005956c5f0f757d37"
 instance_type  ="t2.micro"
 key_name       = aws_key_pair.generated_key.key_name
 security_groups = ["my_security2"]

connection {
     type = "ssh"
     user = "ec2-user"
     private_key = tls_private_key.task_key1.private_key_pem
     host   = aws_instance.final_task_instance.public_ip
 }

provisioner "remote-exec" {
    inline = [
       "sudo yum install httpd php git -y",
        "sudo systemctl  start httpd",
        "sudo systemctl enable httpd",
       
  
   ]
}


 tags={
   Name="final_instance"
  }
}

resource "aws_ebs_volume" "my_volume" {
  availability_zone = "ap-south-1a"
  size              = 1

  tags = {
    Name = "my_volume"
  }
}

resource "aws_ebs_volume" "my_volume1" {
  availability_zone = "ap-south-1b"
  size              = 1

  tags = {
    Name = "my_volume1"
  }
}


resource "aws_volume_attachment" "attachment1" {

  
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.my_volume1.id
  instance_id = aws_instance.final_task_instance.id
  force_detach="true"
  }

  resource "null_resource" "nullremote3" {

 depends_on = [
      aws_volume_attachment.attachment1,]

      connection {

      type  = "ssh"

     user  = "ec2-user"

     private_key = tls_private_key.task_key1.private_key_pem

     host = aws_instance.final_task_instance.public_ip
  
  }


provisioner "remote-exec" {

  inline = [
  
  "sudo mkfs.ext4 /dev/xvda",

  "sudo mount /dev/xvda /var/www/html",

  "sudo rm -rf /var/www/html/*",

  "sudo git clone https://github.com/srinivas-reddy4244/my_task.git/var/www/html/"


    ]

  }
}

resource "aws_s3_bucket" "task_bucket1" {

 depends_on = [
   aws_volume_attachment.attachment1,
   ]

 bucket = "srinivasbuck"
 acl    = "public-read"
 force_destroy = true
 
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
      "Resource": "arn:aws:s3:::srinivasbuck/*"
    }
  ]
}
POLICY
 }


resource "aws_s3_bucket_object" "object" {
  bucket = "srinivasbuck"
  key    = "cloud-computing.png"
  source = "C:/Users/sathish reddy/Desktop/tera/project/cloud-computing.png"
  etag   = "C:/Users/sathish reddy/Desktop/tera/project/cloud-computing.png"

 depends_on = [aws_s3_bucket.task_bucket1,
                 ]

  }



locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_distribution" "task-cloudfront" {

 origin {

     domain_name = aws_s3_bucket.task_bucket1.bucket_regional_domain_name
     origin_id   = "${local.s3_origin_id}"



   custom_origin_config {

      http_port  = 80 
      https_port = 80
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols   = ["TLSv1","TLSv1.1","TLSv1.2"]

     }
  }

 enabled = true

   default_cache_behavior {

      allowed_methods = ["DELETE" , "GET" , "HEAD" , "OPTIONS" ,"PATCH" , "POST" ,"PUT"]
      cached_methods   = ["GET" , "HEAD"]
      target_origin_id = "${local.s3_origin_id}"

      forwarded_values {
          query_string = false

          cookies {
            forward ="none"
          }
      }

      viewer_protocol_policy = "allow-all"
      min_ttl    = 0
      default_ttl= 3600
      max_ttl    = 86400

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



resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.final_task_instance.public_ip} > publicip.txt"
  	}
}


resource "null_resource" "nulllocal1"  {


        depends_on = [
             null_resource.nullremote3,
                ]

        

	provisioner "local-exec" {
	    command = "start  chrome  ${aws_instance.final_task_instance.public_ip}"

   }

}




