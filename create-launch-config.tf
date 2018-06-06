provider "aws" {
  #  access_key = "${var.access_key}"
  #  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

data "template_file" "user_data" {
  #template = "user-data.tpl"
  template = "${file("${path.module}/user-data.tpl")}"
}

data "aws_ami" "server_2016" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2016-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["801119661308"] # Amazon
}

resource "aws_route53_record" "lb_pub_dns" {
  zone_id = "${var.rdsh_dnszone_id}"
  name    = "${var.dns_name}"
  type    = "A"

  alias {
    name                   = "${aws_lb.alb.dns_name}"
    zone_id                = "${aws_lb.alb.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "${aws_route53_record.lb_pub_dns.fqdn}"
  validation_method = "DNS"

  tags {
    Name      = "${var.tag_name}"
    Terraform = "True"
  }

  lifecycle {
    #prevent_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${var.rdsh_dnszone_id}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
}

resource "aws_lb" "alb" {
  name               = "${var.tag_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.lb-sg1.id}"]
  subnets            = ["${var.public_subnets}"]

  tags {
    Name      = "${var.tag_name}"
    Terraform = "True"
  }
}

resource "aws_lb_target_group" "alb_tg" {
  name     = "${var.tag_name}-alb-tg"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = "${var.vpcid}"
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = "${aws_lb.alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = "${aws_acm_certificate_validation.cert.certificate_arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.alb_tg.arn}"
    type             = "forward"
  }
}

resource "aws_launch_configuration" "as_conf" {
  name_prefix     = "${var.tag_name}-lc"
  image_id        = "${data.aws_ami.server_2016.id}"
  instance_type   = "t2.medium"
  security_groups = ["${aws_security_group.rdsh-sg1.id}"]
  key_name        = "${var.key_name}"
  user_data       = "${data.template_file.user_data.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  name                 = "${var.tag_name}-asg"
  launch_configuration = "${aws_launch_configuration.as_conf.name}"
  min_size             = 1
  max_size             = 1
  vpc_zone_identifier  = ["${var.private_subnets}"]

  target_group_arns = ["${aws_lb_target_group.alb_tg.id}"]

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.tag_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Terraform"
    value               = "true"
    propagate_at_launch = false
  }
}

resource "aws_security_group" "lb-sg1" {
  name        = "${var.tag_name}-lb-sg1"
  description = "Security group for accessing RDSH via the Internet"

  vpc_id = "${var.vpcid}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

    #    prefix_list_ids = ["pl-12c4e678"]
  }

  tags {
    Name      = "${var.tag_name}"
    Terraform = "True"
  }
}

resource "aws_security_group" "rdsh-sg1" {
  name        = "${var.tag_name}-rdsh-sg1"
  description = "Security group for accessing RDSH via the LB"

  vpc_id = "${var.vpcid}"

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = ["${aws_security_group.lb-sg1.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

    #    prefix_list_ids = ["pl-12c4e678"]
  }

  tags {
    Name      = "${var.tag_name}"
    Terraform = "True"
  }
}
