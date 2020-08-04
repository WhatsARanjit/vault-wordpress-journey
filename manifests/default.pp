include apache
class { 'wordpress':
  install_dir => '/var/www/html',
}
class { 'mysql::server':
  #root_password    => 'strong_password',
  override_options => {
    'mysqld' => {
      'bind-address' => $mysql_ip,
    },
  },
}
include apache::mod::php
class { 'mysql::bindings':
  php_enable => true,
}
mysql_user { 'root@vault':
  ensure        => present,
  #password_hash => mysql::password($mysql::server::root_password),
  password_hash => mysql::password($vault_mysql_pw),
  require       => Exec['remove install pass']
}
mysql_grant { 'root@vault/*.*':
  ensure     => present,
  privileges => [ 'ALL'],
  table      => '*.*',
  user       => 'root@vault',
  options    => ['GRANT'],
}
