Vagrant.configure "2" do |config|

  # See https://github.com/mitchellh/vagrant/wiki/Available-Vagrant-Boxes for more boxes.
  config.vm.box      = "precise64_base"
  config.vm.box_url  = "http://files.vagrantup.com/precise64.box"

  # Define 4 machines for this tutorial.
  ["mim-1", "mim-2", "tsung-1", "tsung-2"].each do |hostname|
      config.vm.define hostname do |host|
          host.vm.hostname = hostname
      end
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

  config.vm.provision :shell do |sh|
    sh.inline = <<-EOF
      sudo apt-get update
      sudo apt-get install --assume-yes ruby1.9.1-dev build-essential
      gem install chef --no-ri --no-rdoc --no-user-install
    EOF
  end

  config.vm.provision :chef_solo do |chef|
    # this assumes you have travis-ci/travis-cookbooks cloned at ./cookbooks
    chef.cookbooks_path = ["cookbooks/ci_environment"]
    chef.log_level      = :debug

    # Highly recommended to keep apt packages metadata in sync and
    # be able to use apt mirrors.
    chef.add_recipe     "apt"

    # List the recipies you are going to work on/need.
    chef.add_recipe     "build-essential"
    chef.add_recipe     "networking_basic"
    chef.add_recipe     "vim"
    #chef.add_recipe     "travis_build_environment"
    #chef.add_recipe     "git"
    #chef.add_recipe     "java::openjdk7"
    #chef.add_recipe     "kerl"
  end

end
