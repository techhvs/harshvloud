provider "aws" {
  region  = "ap-south-1"
  profile ="harshinfo1398"
}

resource "aws_security_group" "sg_terra"{
  name        = "sg_terra"
  description = "Allows SSH and HTTP"
  vpc_id      = "vpc-58839c30"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
 
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "os1"
  }
}
resource "tls_private_key" "harshkey" {
  algorithm = "RSA"
}

resource "aws_key_pair" "generated_key" {
  key_name   = "harshkey"
  public_key = "${tls_private_key.harshkey.public_key_openssh}"


  depends_on = [
    tls_private_key.harshkey
  ]
}

resource "local_file" "key-file" {
  content  = "${tls_private_key.harshkey.private_key_pem}"
  filename = "harshkey.pem"


  depends_on = [
    tls_private_key.harshkey
  ]
}
resource "aws_instance" "os1" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.generated_key.key_name
  security_groups = [ "sg_terra" ]

  provisioner "remote-exec" {
    connection {
    agent    = "false"
    type     = "ssh"
    user     = "ec2-user"
    private_key ="${tls_private_key.harshkey.private_key_pem}"
    host     = "${aws_instance.os1.public_ip}"
  }
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "os1"
  }
}
resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.os1.availability_zone
  size              = 1

  tags = {
    Name = "vol1"
  }
}
resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs1.id
  instance_id = aws_instance.os1.id
  force_detach = true
}
output "myip" {
  value = aws_instance.os1.public_ip
}

resource "null_resource" "nullip" {
  provisioner "local-exec" {
    command = "echo ${aws_instance.os1.public_ip} "
  }
}
resource "null_resource" "nullmount" {
  depends_on = [
    aws_volume_attachment.ebs_attach,
  ]

  connection {
    agent    = "false"
    type     = "ssh"
    user     = "ec2-user"
    private_key ="${tls_private_key.harshkey.private_key_pem}"
    host     = "${aws_instance.os1.public_ip}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/hsdh",
      "sudo mount /dev/hsdh /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/techhvs/harshvloud.git  /var/www/html"
    ]
  }
}
resource "aws_s3_bucket" "harshbucketnew" {
  bucket = "harshbucket1398"
  acl    = "public-read"

  versioning {
    enabled = true
  }
 
  tags = {
    Name = "harshbucketnew"
    Environment = "Dev"
  }
}
resource "aws_cloudfront_distribution" "terra_cloudfront" {
    origin {
        domain_name = "d2ozc696nmrhmc.cloudfront.net"
        origin_id = "harshbucket1398"


        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }
       
    enabled = true


    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "harshbucket1398"

        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
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
resource "null_resource" "nullremote" {
  depends_on = [
    null_resource.nullmount,
  ]

 
  provisioner "local-exec" {
    command = "start firefox ${aws_instance.os1.public_ip}"
  }
}