variable "region" {
  type = string
}

variable "buckets" {
  type = list(object({
    name           = string
    force_destroy  = bool
    versioning     = bool
    website        = bool
    index_document = optional(string, "index.html")
    error_document = optional(string, "error.html")
  }))
}
