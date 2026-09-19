environment   = "prod"
aws_region    = "eu-west-3"
project_name  = "todo-app"
instance_type = "t3.medium"
key_name      = "todo-app"
ssh_cidr      = "0.0.0.0/0"
volume_size   = 40

# Domaine DuckDNS (le reverse proxy Traefik route l'app + outils par chemins)
# domain_name       = "madakhoun.duckdns.org"
# route53_zone_id   = ""