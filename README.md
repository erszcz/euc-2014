# Intro to load testing with Tsung


## Who am I?

- Radek Szymczyszyn <radoslaw.szymczyszyn@erlang-solutions.com>
- ejabberd/MongooseIM engineer
  at [Erlang Solutions Kraków](https://www.erlang-solutions.com/)
- github.com/lavrin


## Setting up the environment

**For VM management we'll need VirtualBox and Vagrant**.
I successfully tested the environment with versions 4.3.10 and 1.5.3 on MacOS X,
and with 4.3.12 and 1.6.3 on Ubuntu 13.10.
Please note that _there are unresolved issues_ when using older versions!
I guess VirtualBox 4.3.x and Vagrant 1.5.y should suffice.

We will use a set of up to 4 virtual machines for the tutorial:
two will be used for load generation and two will be our system under test.

Let's setup the tutorial repository and the first MongooseIM
(system under test) VM:

    git clone git://github.com/lavrin/euc-2014.git euc-2014-tsung
    cd euc-2014-tsung
    git submodule update -i
    vagrant up mim-1  # this will take a few minutes

Hopefully, Vagrant finishes without errors.
Before setting up another MongooseIM VM, let's bring the first server node up:

    vagrant ssh mim-1
    sudo mongooseimctl start
    sudo mongooseimctl debug

An Erlang shell attached to the node should appear, with a prompt like:

    Erlang/OTP 17 [erts-6.0] [source-07b8f44] [64-bit] [smp:2:2]
      [async-threads:10] [hipe] [kernel-poll:false]

    Eshell V6.0  (abort with ^G)
    (mongooseim@mim-1)1>

This means the installation went fine.
We can leave the shell with `control+c, control+c`.
Let's bring up another MongooseIM VM and verify that it automatically
joined the cluster:

    vagrant up mim-2  # this will take a few minutes
    vagrant ssh mim-2
    sudo mongooseimctl start
    sudo mongooseimctl mnesia running_db_nodes

Two nodes will most likely appear:

    ['mongooseim@mim-1','mongooseim@mim-2']

One more test we ought to do to ensure the service is running fine
on both VMs is checking whether it listens for XMPP connections:

    telnet mim-1 5222
    ^D

We should see something like:

    Trying 172.28.128.11...
    Connected to mim-1.
    Escape character is '^]'.
    <?xml version='1.0'?><stream:stream xmlns='jabber:client'
      xmlns:stream='http://etherx.jabber.org/streams' id='2096410314'
      from='localhost' version='1.0'><stream:error><xml-not-well-formed
      xmlns='urn:ietf:params:xml:ns:xmpp-streams'/></stream:error>
      </stream:stream>
    Connection closed by foreign host.

We can do the same for the other node:

    telnet mim-2 5222

We also need to set up the Tsung nodes:

    vagrant up tsung-1 tsung-2

If the environment is fine, then let's stop some of the nodes for now:

    vagrant halt mim-2 tsung-2


## Troubleshooting


### Vagrant can't `ssh` into a virtual machine

Vagrant might sometimes give you a "Connection timeout" error when trying
to bring a machine up or ssh to it.
This is an issue with DHCP and/or VirtualBox DHCP server:

    $ vagrant up tsung-1
    Bringing machine 'tsung-1' up with 'virtualbox' provider...
    ==> tsung-1: Importing base box 'precise64_base'...
    ==> tsung-1: Matching MAC address for NAT networking...
    ==> tsung-1: Setting the name of the VM: euc-2014_tsung-1_1401796905992_8586
    ==> tsung-1: Fixed port collision for 22 => 2222. Now on port 2200.
    ==> tsung-1: Clearing any previously set network interfaces...
    ==> tsung-1: Preparing network interfaces based on configuration...
        tsung-1: Adapter 1: nat
        tsung-1: Adapter 2: hostonly
    ==> tsung-1: Forwarding ports...
        tsung-1: 22 => 2200 (adapter 1)
    ==> tsung-1: Running 'pre-boot' VM customizations...
    ==> tsung-1: Booting VM...
    ==> tsung-1: Waiting for machine to boot. This may take a few minutes...
        tsung-1: SSH address: 127.0.0.1:2200
        tsung-1: SSH username: vagrant
        tsung-1: SSH auth method: private key
        tsung-1: Warning: Connection timeout. Retrying...
        tsung-1: Warning: Connection timeout. Retrying...
        tsung-1: Warning: Connection timeout. Retrying...


**Trying again might work**

Issuing `vagrant halt -f <the-machine>` and `vagrant up <the-machine>`
(possibly more than once) might make the machine accessible again.


**Manually reconfiguring will work, but it's troublesome**

If not, then it's necessary to `vagrant halt -f <the-machine>`,
toggle the `v.gui = false` switch in `Vagrantfile` to `v.gui = true`
and `vagrant up <the-machine>` again.

Once the GUI shows up we need to login with `vagrant:vagrant`
and (as `root`) create file `/etc/udev/rules.d/70-persistent-net.rules`
the contents of which must be as follows (one rule per line!):

    SUBSYSTEM=="net", ACTION=="add", DRIVERS=="pcnet32", ATTR{address}=="?*", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"
    SUBSYSTEM=="net", ACTION=="add", DRIVERS=="e1000", ATTR{address}=="?*", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth1"

Unfortunately, the GUI doesn't allow for copy-pasting the contents,
so they have to be typed in.
With this file in place, the machine should be SSH-accessible after the
next reboot.


**Destroying and recreating the machine will work, but takes some time**

Alternatively, you might just `vagrant destroy <the-machine>`
and recreate it following the steps from _Setting up the environment_.


**Why does this happen?**

This problem is caused by random ordering of the network devices detected
at guest system boot up.
That is, sometimes Adapter 1 is detected first and gets called `eth0`
while Adapter 2 is `eth1` and sometimes it's the other way around.

Since the guest network configuration is bound to `ethN` identifier,
not to the device itself and the hypervisor network configuration is bound
to adapter number (not the `ethN` identifier),
the situation might sometimes lead to a mismatch:
the guest system tries to use a static address for a VirtualBox NAT adapter
which ought to be configured via DHCP.
This invalid setup leads to SSH failing to establish a connection.
