# Create Autoscal Explicit Proxy cluster using Terraform

## Usage
 - To create the cluster
   - terraform/terraform apply
   - Type in a deployment specific name
 - To destroy the cluster
   - terraform/terraform destroy
 - AWS CLI
   - you'll need AWS cli installed on your machine with access key & secret key

## Terraform
 - Creates the below items in us-east-2 region 
   - VPC
   - Subnet
   - Internet Gateway
   - Routing
   - ELB using tcp at port 8080
   - Autoscale BIG-IP cluster configured for Explict Proxy at port 8080
     - DO, AS3, and TS is deployed and used to configure the device.


## Once deployed
   - The output.tf will provide the DNS name for the ELB
   - It will take about 15 minutes for the environment to become ready to test
   - To test point your client to the DNS name for the ELB at port 8080
   - Example: curl -v -x elb-proxy1-96343303.us-east-2.elb.amazonaws.com:8080 https://www.f5.com
   - The AS3 declaration contains a datagroup that only allows specific URLs through the proxy.
     - example.com (http and https is available)
     - google.com
     - f5.com
     - nginx.com
     - chase.com
     - eunops.org (this is to test http)

