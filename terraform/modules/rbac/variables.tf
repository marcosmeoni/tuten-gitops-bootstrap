variable "environment" {
  type = string
}

variable "namespaces" {
  type = list(string)
}

variable "labels" {
  type    = map(string)
  default = {}
}
