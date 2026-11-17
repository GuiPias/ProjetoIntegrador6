output "bastion_ip_publico" {
  description = "IP público (Elastic IP) do bastion, ponto de entrada administrativo."
  value       = aws_eip.bastion.public_ip
}

output "app_ip_publico" {
  description = "IP público (Elastic IP) da aplicação."
  value       = aws_eip.app.public_ip
}

output "nat_ip_publico" {
  description = "IP público do NAT Gateway (IP de saída da sub-rede privada)."
  value       = aws_eip.nat.public_ip
}

output "ips_privados" {
  description = "IPs privados das instâncias."
  value = {
    bastion = aws_instance.bastion.private_ip
    app     = aws_instance.app.private_ip
    banco   = aws_instance.db.private_ip
  }
}

output "app_url" {
  description = "URL da aplicação (HTTPS, certificado autoassinado)."
  value       = "https://${aws_eip.app.public_ip}"
}

output "ssh_bastion" {
  description = "Comando para acessar o bastion (usuário padrão da imagem Ubuntu)."
  value       = "ssh ubuntu@${aws_eip.bastion.public_ip}"
}

output "ssh_banco_via_bastion" {
  description = "Comando para acessar o banco passando pelo bastion."
  value       = "ssh -J ubuntu@${aws_eip.bastion.public_ip} ubuntu@${aws_instance.db.private_ip}"
}
