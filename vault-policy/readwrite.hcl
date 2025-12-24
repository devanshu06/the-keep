path "stage/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "stage/metadata/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "prod/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "prod/metadata/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
