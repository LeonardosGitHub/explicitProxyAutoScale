############################################
# BUILDING APPLICATION CERTIFICATE FOR ELB #
############################################

resource "aws_iam_server_certificate" "elb_cert" {
  name             = "elb_cert_${var.emailid}"
  certificate_body = file("crt/secexample.com.crt")
  private_key      = file("crt/secexample.com.key")
}

############################################
# BUILDING ELB                             #
############################################

resource "aws_elb" "f5-autoscale-waf-elb" {
  name = "waf-${var.LOBname}"

  cross_zone_load_balancing = true
  security_groups           = [aws_security_group.elb.id]
  subnets                   = [aws_subnet.public-a.id, aws_subnet.public-b.id]

  listener {
    lb_port            = 443
    lb_protocol        = "https"
    instance_port      = var.bigip_port
    instance_protocol  = "http"
    ssl_certificate_id = aws_iam_server_certificate.elb_cert.arn
  }
}

###################################
# BUILDING SECURITY GROUP FOR ELB #
###################################

resource "aws_security_group" "elb" {
  name   = "terraform-example-elb"
  vpc_id = aws_vpc.terraform-vpc-LOBexample.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.restrictedSrcAddress
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.restrictedSrcAddress
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


############################################
# DEPLOYING CFT                            #
############################################

resource "aws_cloudformation_stack" "f5-autoscale-waf" {
  name         = "waf-${var.LOBname}-${aws_vpc.terraform-vpc-LOBexample.id}"
  capabilities = ["CAPABILITY_IAM"]

  parameters = {
    #DEPLOYMENT
    deploymentName           = "waf-${var.LOBname}"
    Vpc                      = aws_vpc.terraform-vpc-LOBexample.id
    availabilityZones        = "${var.aws_region}a,${var.aws_region}b"
    subnets                  = "${aws_subnet.public-a.id},${aws_subnet.public-b.id}"
    bigipElasticLoadBalancer = aws_elb.f5-autoscale-waf-elb.name
    allowUsageAnalytics      = "No"

    #INSTANCE CONFIGURATION
    instanceType         = "m5.xlarge"
    imageName            = "Best"
    bigIpModules         = "ltm:nominal,asm:nominal"
    sshKey               = var.aws_keypair
    throughput           = "25Mbps"
    adminUsername        = "cluster-admin"
    managementGuiPort    = 8443
    timezone             = "UTC"
    ntpServer            = "0.pool.ntp.org"
    restrictedSrcAddress = "0.0.0.0/0"
    customImageId        = "OPTIONAL"
    #customImageId        = "ami-062f8fe9965020f99"

    #AUTO SCALING CONFIGURATION
    scalingMinSize          = 2
    scalingMaxSize          = 4
    highCpuThreshold        = 30
    lowCpuThreshold         = 20
    scaleDownBytesThreshold = 20000
    scaleUpBytesThreshold   = 45000
    notificationEmail       = var.waf_emailid != "" ? var.waf_emailid : var.emailid

    #WAF VIRTUAL SERVICE CONFIGURATION
    virtualServicePort      = var.bigip_port
    applicationPort         = var.web_server_port
    restrictedSrcAddressApp = "0.0.0.0/0"

    appInternalDnsName      = "LOBexample.example.com"
    applicationPoolTagKey   = "service"
    applicationPoolTagValue = "discovery"
    policyLevel             = "medium"
    declarationUrl          = "https://raw.githubusercontent.com/LeonardosGitHub/autoscaleWAF/master/terraform/as3/as3DeclarationMediumWAF.json"


    #BIGIPModules = "ltm:nominal,asm:nominal"

    #TAGS
    application = "f5app"
    environment = "f5env"
    group       = "f5group"
    owner       = "f5owner"
    costcenter  = "f5costcenter"
  }

  #CloudFormation templates triggered from Terraform must be hosted on AWS S3.
  #Documentation on gitHub, https://github.com/F5Networks/f5-aws-cloudformation/tree/master/supported/autoscale/waf/via-lb/1nic/existing-stack/bigiq
  template_url = "https://wafautoscalecft.s3.us-east-2.amazonaws.com/f5-payg-autoscale-bigip-waf_custom2.template"
}

