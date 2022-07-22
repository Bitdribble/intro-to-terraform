output "public_ip" {
  value       = aws_instance.main.public_ip
  description = "The public IP of the web server"
}

output "web_server_private_ip" {
  value = aws_instance.main.private_ip
  description = "The private IP of the web server"
}

