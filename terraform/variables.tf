variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "todo-app"
}

variable "environment" {
  description = "Environnement cible (dev ou prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment doit être 'dev' ou 'prod'."
  }
}

variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-3"
}

variable "key_name" {
  description = "Nom de la paire de clés EC2 existante dans la région"
  type        = string
  default     = "todo-app"
}

variable "vpc_id" {
  description = "ID du VPC où créer les instances (par défaut : VPC par défaut)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "ID du sous-réseau public où créer les instances (par défaut : 1er subnet public du VPC)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "volume_size" {
  description = "Taille du disque racine (Go). Augmenter en prod (SonarQube, Prometheus, Grafana, Loki…)"
  type        = number
  default     = 20
}

variable "ami_id" {
  description = "AMI utilisée (par défaut : dernière Ubuntu 22.04 officielle de la région)"
  type        = string
  default     = ""
}

variable "ssh_cidr" {
  description = "CIDR autorisé pour SSH (recommandé : votre IP /32)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "domain_name" {
  description = "Domaine utilisé pour le reverse-proxy (laisser vide si aucun)"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "ID de la zone Route 53 (requis si domain_name est défini)"
  type        = string
  default     = ""
}