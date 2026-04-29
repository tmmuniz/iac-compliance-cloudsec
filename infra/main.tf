module "cloudsec_lab" {
  source = "./modules/cloudsec-lab"

  project_name           = var.project_name
  environment            = var.environment
  instance_type          = var.instance_type
  allowed_public_ip_cidr = var.allowed_public_ip_cidr
  ec2_instance_count     = var.ec2_instance_count
  adm_bucket_name        = var.adm_bucket_name
  github_repository      = var.github_repository
  enable_ssh_access      = var.enable_ssh_access
  force_destroy_buckets  = var.force_destroy_buckets
  ssh_public_key         = var.ssh_public_key
}
