output "public_ip" {
  description = "Public IP address of the EC2 KVM host"
  value       = aws_instance.host.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.host.id
}

output "instance_type" {
  description = "EC2 instance type used"
  value       = aws_instance.host.instance_type
}

output "private_key_path" {
  description = "Path to the generated SSH private key"
  value       = local_sensitive_file.private_key.filename
}

output "ssh_command" {
  description = "Command to SSH into the host"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ubuntu@${aws_instance.host.public_ip}"
}

output "vnc_tunnel_command" {
  description = "Command to establish SSH tunnel for VNC"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} -N -L 5900:127.0.0.1:5900 ubuntu@${aws_instance.host.public_ip}"
}

output "web_url" {
  description = "URL to access the Red Star OS web gateway"
  value       = "http://${aws_instance.host.public_ip}"
}
