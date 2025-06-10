output "jenkins_url" {
  value = "http://${aws_instance.ci_server.public_ip}:8080"
}

output "sonarqube_url" {
  value = "http://${aws_instance.ci_server.public_ip}:9000"
}

output "eb_env_endpoint" {
  value = aws_elastic_beanstalk_environment.env.endpoint_url
}
