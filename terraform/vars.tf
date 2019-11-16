
variable "web_server_ami" {
  type = map(string)

  default = {
    "us-east-1"      = "ami-a4c7edb2"
    "ap-southeast-1" = "ami-77af2014"
    "us-east-2"      = "ami-8a7859ef"
    "us-west-2"      = "ami-6df1e514"
  }
}

variable "aws_region" {
  description = "aws region (default is us-east-2)"
  default     = "us-east-2"
}

variable "bigip_port" {
  description = "The BIG-IP load balancer port for HTTP requests"
}

variable "web_server_port" {
  description = "The port the web server will use for HTTP requests"
}

variable "aws_keypair" {
  description = "The name of an existing key pair. In AWS Console: NETWORK & SECURITY -> Key Pairs"
  default     = "f5_aws_acct_keypair"
}

variable "emailid" {
  description = "emailid"
  default     = "leonardo.simon@f5.com"
}

variable "waf_emailid" {
  description = "waf_emailid"
  default     = "leonardo.simon@f5.com"
}

variable "LOBname" {
  description = "LOBname"
  #default     = "secexample"
}

variable "restrictedSrcAddress" {
  type        = list(string)
  description = "Lock down management access by source IP address or network"
  default     = ["0.0.0.0/0", "10.0.0.0/16"]
}

#variable "aws_alias" {
#  description = "Link alias to AWS Console"
#  #leonardo added
#  default = "terraform-usr-leonardo"
#}
