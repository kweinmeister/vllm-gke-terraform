resource "null_resource" "validate_script_permissions" {
  triggers = {
    script_content = file("${path.module}/scripts/validate-cache.sh")
  }

  provisioner "local-exec" {
    command = "test -x ${path.module}/scripts/validate-cache.sh || (echo 'ERROR: scripts/validate-cache.sh is not executable. Please run: chmod +x scripts/validate-cache.sh' && exit 1)"
  }
}

