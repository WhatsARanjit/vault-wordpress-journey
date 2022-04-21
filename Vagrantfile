# Vault Info
vault_ip        = ENV['VAULT_IP']      || '192.168.50.5'
vault_version   = ENV['VAULT_VERSION'] || '1.4.2'
vault_os        = ENV['VAULT_OS']      || 'linux'
vault_arch      = ENV['VAULT_ARCH']    || 'amd64'
vault_url       = "https://releases.hashicorp.com/vault/#{vault_version}/vault_#{vault_version}_#{vault_os}_#{vault_arch}.zip"
vault_token     = ENV['VAULT_TOKEN']

# Wordpress Info
wp_ip           = ENV['WP_IP']         || '192.168.50.4'
wp_version      = ENV['WP_VERSION']    || '5.4.2'
wp_os           = ENV['WP_OS']         || 'linux'
wp_arch         = ENV['WP_ARCH']       || 'amd64'
vault_agent_url = "https://releases.hashicorp.com/vault/#{vault_version}/vault_#{vault_version}_#{wp_os}_#{wp_arch}.zip"
wp_download_url = "https://wordpress.org/wordpress-#{wp_version}.tar.gz"
vault_mysql_pw  = ENV['VAULT_MYSQL_PW'] || 'strong_password'
vault_role_id   = ENV['VAULT_ROLE_ID']  || nil

Vagrant.configure(2) do |config|

  # Wordpress VM
  config.vm.define 'wp' do |wp|
    # Base box
    wp.vm.box      = 'puppetlabs/centos-7.2-64-nocm'
    wp.vm.hostname = 'wordpress'

    wp.vm.network :private_network, :ip => wp_ip, :ipv6 => false
    wp.vm.provision :hosts, :sync_hosts => true

    # Only on vagrant up
    if ARGV[0] == 'up'
      # Install Puppet
      wp.vm.provision 'shell',
        name: 'install_puppet',
        inline: <<-SHELL
        sudo wget https://yum.puppetlabs.com/RPM-GPG-KEY-puppet
        sudo rpm --import RPM-GPG-KEY-puppet
        sudo yum install -y https://yum.puppet.com/puppet5-release-el-7.noarch.rpm
        sudo yum install -d 0 -y puppet-agent
        sudo service firewalld stop
      SHELL

      # Install modules and Wordpress
      wp.vm.provision 'shell',
        name: 'install_wordpress',
        inline: <<-SHELL
        puppet module install puppetlabs/apache --modulepath /opt/puppetlabs/puppet/modules
        puppet module install puppetlabs/mysql --modulepath /opt/puppetlabs/puppet/modules
        puppet module install hunner/wordpress --modulepath /opt/puppetlabs/puppet/modules
      SHELL

      # Install Wordpress with Puppet
      wp.vm.provision 'puppet' do |puppet|
        puppet.facter = {
          'mysql_ip'       => wp_ip,
          'vault_mysql_pw' => vault_mysql_pw,
        }
      end
    end

    # If AppRole values are available
    if vault_role_id
      # Vault Agent
      wp.vm.provision 'shell',
        name: 'install_vault_agent',
        inline: <<-"SHELL"
        [[ -f vault ]] || (
          wget -q -O vault.zip #{vault_agent_url}
          sudo /opt/puppetlabs/bin/puppet resource package unzip ensure=installed
          unzip vault.zip
          sudo install ~vagrant/vault /usr/local/bin
        )
      SHELL

      wp.vm.provision 'shell',
        name: 'run_vault_agent',
        env: {
          "VAULT_ADDR"  => "http://#{vault_ip}:8200",
          "VAULT_TOKEN" => ENV['VAULT_TOKEN'],
        },
        inline: <<-"SHELL"
        echo "Vault address: $VAULT_ADDR"
        vault write -f auth/approle/role/#{vault_role_id}/secret-id \
          | grep -m1 secret_id \
          | awk '{print \$2}' > /vagrant/secretid
        
        # Recycle Vault Agent
        sudo pkill vault
        vault agent -config=/vagrant/policy/vault-agent.hcl > ~/vault-agent.log 2>&1 &
        echo 'Vault Agent running...'
      SHELL
    end
  end
end

Vagrant.configure(2) do |config|

  # Vault VM
  config.vm.define 'vault' do |vault|
    # Base box
    vault.vm.box      = 'bento/ubuntu-16.04'
    vault.vm.hostname = 'vault'

    vault.vm.network :private_network, :ip => vault_ip, :ipv6 => false
    vault.vm.provision :hosts, :sync_hosts => true

    # Install Vault
    vault.vm.provision 'shell',
      name: 'install_vault',
      inline: <<-"SHELL"
      wget -q -O vault.zip #{vault_url}
      sudo apt-get install -y zip
      unzip vault.zip
      sudo install ~vagrant/vault /usr/local/bin
      echo 'Starting Vault...'
      vault server -dev -dev-listen-address='#{vault_ip}:8200' -dev-root-token-id='root' > ~/vault.init 2> vault.log &
      echo 'Vault started'
    SHELL
  end
end
