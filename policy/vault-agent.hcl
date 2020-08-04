pid_file = "/tmp/vault-agent.pid"

vault {
  address = "http://vault:8200"
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "/vagrant/roleid"
      secret_id_file_path = "/vagrant/secretid"
    }
  }

  sink "file" {
    config = {
      path = "/tmp/wordpress-token"
    }
  }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = true
}

template {
  source      = "/vagrant/policy/wp-config.php-static.ctmpl"
  destination = "/var/www/html/wp-config.php"
}
