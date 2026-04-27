module "cloudsec_lab" {
  source = "./modules/cloudsec-lab"

  project_name           = var.project_name
  environment            = var.environment
  instance_type          = var.instance_type
  allowed_public_ip_cidr = var.allowed_public_ip_cidr
  ec2_instance_count     = var.ec2_instance_count
  prowler_reports_bucket_name = var.prowler_reports_bucket_name
}
