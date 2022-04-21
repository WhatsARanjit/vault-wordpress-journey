# Deploy Static Wordpress

Do this step ahead of time because deploying Wordpress takes a few minutes.

```shell
vagrant up wp
```

View webpage at http://192.168.50.4 or the set IP.

# Checkout WP static configuration

```shell
vagrant ssh wp
view /var/www/html/wp-config.php
```

Scroll down to the `/** MySQL database username */` and `/** MySQL database password */` specifications.  Note credentials in plain-text.

# Launch Vault node

Quit out back to your terminal.

```shell
vagrant up vault
```

# Configure Vault for AppRole and secrets

```shell
vagrant ssh vault
# Vault ENVs
export VAULT_ADDR=http://vault:8200
export VAULT_TOKEN=root
vault status

# V1
#vault secrets enable -version=1 kv
#vault kv put kv/wordpress username=wordpress password=password

vault kv put secret/wordpress username=wordpress password=password
vault policy write wordpress /vagrant/policy/wordpress_static.hcl
cat /vagrant/policy/wordpress_static.hcl
```

# Configure AppRole

```shell
vault auth enable approle
vault write auth/approle/role/wordpress token_policies="wordpress" \
  token_ttl=1m token_max_ttl=30m
vault read auth/approle/role/wordpress
```

# Look at RoleID

```shell
vault read auth/approle/role/wordpress/role-id
```

# Preview SecretID

```shell
vault write -f auth/approle/role/wordpress/secret-id
```

# Run Vagrant provisioner to grab role/secret IDs

Quit out back to your terminal.

```shell
export VAULT_IP=192.168.50.5
export VAULT_ADDR=http://${VAULT_IP}:8200
export VAULT_TOKEN=root
export VAULT_ROLE_ID=wordpress
vault read auth/approle/role/$VAULT_ROLE_ID/role-id \
  | grep role_id \
  | awk '{print $2}' > roleid
cat roleid
```

Setting the ENV variable of `VAULT_ROLE_ID` will tell the provisioning process to install the Vault Agent and use the roleid to pull a secretid.

```shell
vagrant provision wp
```

Switch to the Wordpress VM

```shell
sudo cat /root/vault-agent.log
view /vagrant/policy/wp-config.php-static.ctmpl
```

# Change password

```shell
vagrant ssh wp
mysql -u root mysql
SELECT user, host, password FROM user WHERE user='wordpress';
SET PASSWORD FOR 'wordpress'@'localhost' = PASSWORD('new_password');
SELECT user, host, password FROM user WHERE user='wordpress';
quit
```
View website, which is now broken.

# Update password in Vault

```shell
export VAULT_ADDR=http://vault:8200
export VAULT_TOKEN=root

# V1
# vault kv put kv/wordpress username=wordpress password=new_password

vault kv put secret/wordpress username=wordpress password=new_password
#sudo cat /tmp/wordpress-token
#vault token lookup <token>
```

Let's follow the Vault Agent back on the Wordpress machine

```shell
sudo tail -f /root/vault-agent.log
```

# Setup dynamic secrets

```shell
#mysql -u root mysql -D mysql -pstrong_password -e 'ALTER TABLE user MODIFY user VARCHAR(20);'
vault secrets enable database
vault write database/config/wordpress \
  plugin_name=mysql-legacy-database-plugin \
  connection_url="{{username}}:{{password}}@tcp(wp:3306)/" \
  allowed_roles="wordpress" \
  username="root" \
  password="strong_password"
vault write database/roles/wordpress \
  db_name="wordpress" \
  creation_statements="CREATE USER '{{name}}'@'localhost' IDENTIFIED BY '{{password}}'; GRANT SELECT ON *.* TO '{{name}}'@'localhost';" \
  revocation_statements="REVOKE ALL PRIVILEGES, GRANT OPTION FROM '{{name}}'@'localhost'; DROP USER '{{name}}'@'localhost';" \
  default_ttl="1m" \
  max_ttl="5m"
```

# Test DB secret

```shell
vault read database/creds/wordpress
```

Show new database user on Wordpress' MySQL instance

```shell
mysql -u root mysql
SELECT user, host, password FROM user;
quit
```

# Update workflow to use dynamic secrets

Update the Vault policy to use the dynamic path

```shell
vault policy write wordpress /vagrant/policy/wordpress_dynamic.hcl
```

Update the Vault Agent from the provisioning VM

* Update `policy/vault-agent.hcl` and change the source template from `/vagrant/policy/wp-config.php-static.ctmpl` to `/vagrant/policy/wp-config.php-dynamic.ctmpl`.
* Show that `/vagrant/policy/wp-config.php-dynamic.ctmpl` uses the dynamic path

```shell
view policy/wp-config.php-dynamic.ctmpl
```

Re-run the provisioner of the Wordpress VM which will restart the Vault Agent

```shell
vagrant provision wp
```

Let's follow the Vault Agent back on the Wordpress machine

```shell
sudo tail -f /root/vault-agent.log
```

Check the contents of the Wordpress config file on the Wordpress VM now

```shell
view /var/www/html/wp-config.php
```

Watch the password change if you want

```shell
watch -n 10 grep DB_USER /var/www/html/wp-config.php
```

# Demo Reset

From the provisioning VM


```shell
vagrant destroy -f
unset VAULT_ROLE_ID
rm -f roleid secretid
```
