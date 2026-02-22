output "security_group_id" {
  value = aws_security_group.tf_flask_sg.id
}
#--------------------------------key pair--------------------------------------------------------#
output "key_name" {
  value = aws_key_pair.tf_flask_key.key_name
}
#---------------------------------ec2-------------------------------------------------------#
output "ec2_public_ip" {
  value = aws_instance.tf_flask_ec2.public_ip
}
#---------------------------------ecr-------------------------------------------------------#
output "ecr_repository_url" {
  value = aws_ecr_repository.tf_flask_ecr.repository_url
}