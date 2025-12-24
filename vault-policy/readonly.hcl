path "stage/data/*" {
  capabilities = ["read", "list"]
}

path "stage/metadata/*" {
  capabilities = ["read", "list"]
}

path "prod/data/*" {
  capabilities = ["read", "list"]
}

path "prod/metadata/*" {
  capabilities = ["read", "list"]
}
