hosts = [
    {
        :name => "mim-1",
        :ip => "172.28.128.11"
    },
    {
        :name => "mim-2",
        :ip => "172.28.128.12"
    },
    {
        :name => "tsung-1",
        :ip => "172.28.128.21"
    },
    {
        :name => "tsung-2",
        :ip => "172.28.128.22"
    }
]

Vagrant.configure "2" do |config|

  # See https://github.com/mitchellh/vagrant/wiki/Available-Vagrant-Boxes for more boxes.
  config.vm.box      = "precise64_base"
  config.vm.box_url  = "http://files.vagrantup.com/precise64.box"

  # Define 4 machines for this tutorial.
  hosts.each do |host|
      config.vm.define host[:name] do |host_config|
          host_config.vm.hostname = host[:name]
          host_config.vm.network "private_network", ip: host[:ip]
      end
  end

  config.vm.define "tsung-1" do |tsung_1|
      tsung_1.vm.network "forwarded_port", guest: 8080, host: 8080
  end

  # Don't use this by default but keep for convenience;
  # if Vagrant can't ssh into the box the GUI is the only way to reset
  # network interfaces.
  config.vm.provider "virtualbox" do |v|
    #v.gui = true
    v.gui = false
  end

  # change default username if needed
  config.ssh.username = "vagrant"

  config.vm.provider "virtualbox" do |vm|
    # changing nictype partially helps with Vagrant issue #516, VirtualBox NAT interface chokes when
    # # of slow outgoing connections is large (in dozens or more).
    vm.customize ["modifyvm", :id, "--nictype1", "Am79C973", "--memory", "1024", "--cpus", "2", "--ioapic", "on"]

    # see https://github.com/mitchellh/vagrant/issues/912
    vm.customize ["modifyvm", :id, "--rtcuseutc", "on"]
  end

  udev_persistent_net_path = "/etc/udev/rules.d/70-persistent-net.rules"
  udev_persistent_net_rules = <<-EORULES
    # PCI device 0x1022:/sys/devices/pci0000:00/0000:00:03.0 (pcnet32)
    SUBSYSTEM=="net", ACTION=="add", DRIVERS=="pcnet32", ATTR{address}=="?*", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"

    # PCI device 0x8086:/sys/devices/pci0000:00/0000:00:08.0 (e1000)
    SUBSYSTEM=="net", ACTION=="add", DRIVERS=="e1000", ATTR{address}=="?*", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth1"
  EORULES

  config.vm.provision :shell do |sh|
    sh.inline = <<-EOF
      sudo apt-get update
      sudo apt-get install --no-install-recommends --assume-yes udev ruby1.9.1-dev build-essential
      [ -x "/opt/vagrant_ruby/bin/chef-solo" ] || gem install chef --no-ri --no-rdoc --no-user-install
      [ -d "#{udev_persistent_net_path}" ] && rmdir "#{udev_persistent_net_path}"
      echo '#{udev_persistent_net_rules}' > "#{udev_persistent_net_path}"
    EOF
  end

  config.vm.provision :chef_solo do |chef|
    # this assumes you have travis-ci/travis-cookbooks cloned at ./cookbooks
    chef.cookbooks_path = ["cookbooks/ci_environment"]
    chef.log_level      = :debug

    # List the recipies you are going to work on/need.
    chef.add_recipe     "apt"
    chef.add_recipe     "build-essential"
    chef.add_recipe     "euc2014"
    chef.add_recipe     "vim"
    chef.add_recipe     "git"
    chef.add_recipe     "esl-packages"
    chef.add_recipe     "esl-erlang"
    chef.add_recipe     "tsung-git"
    chef.add_recipe     "mongooseim"
  end

end
