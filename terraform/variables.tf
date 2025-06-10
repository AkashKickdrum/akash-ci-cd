variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}
variable "key_pair_name" {
  type    = string
  default = "akash-ci-cd-key"
}
variable "instance_type" {
  type    = string
  default = "t2.medium"
}
variable "eb_app_name" {
  type    = string
  default = "spring-version-app"
}
variable "eb_env_name" {
  type    = string
  default = "spring-version-env"
}
variable "jenkins_admin_user" {
  type    = string
  default = "akash"
}
