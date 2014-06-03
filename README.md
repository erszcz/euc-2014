# Intro to load testing with Tsung


## Who am I?

- Radek Szymczyszyn <radoslaw.szymczyszyn@erlang-solutions.com>
- ejabberd/MongooseIM engineer at Erlang Solutions Kraków
- github.com/lavrin


## What is load testing?

TODO

## What is Tsung?

## Exercises

- one Tsung, one MongooseIM

- one Tsung, two MongooseIMs

- two Tsungs, two MongooseIMs


## Caveats and extra info

- Tsung is dumb, it doesn't understand XMPP
- 1024 open file descriptor limit (`ulimit -n`);
  for more than 65k outgoing connections it's necessary to use multiple
  virtual interfaces
- Tsung controller is a single point of serialization -- severe delays
  and test failures when generating massive load
- log level debug and dump traffic to see actual XMPP stanzas
- scripts for making graphs
- the paths to ssh/erlang/Tsung must match on all machines for distributed
  testing to work
- XMPP version 1.0 by default advertised by Tsung causes ejabberd/MongooseIM
  to refuse plain text authentication


## Setting up the environment

We will use a set of up to 4 virtual machines for the tutorial:
two will be used for load generation and two will be our system under test.
For VM management we'll need VirtualBox and Vagrant;
I used versions 4.3.10 and 1.5.3 respectively,
when setting up the environment for the tutorial.

Let's setup the tutorial repository and the first MongooseIM
(system under test) VM:

    git clone git://github.com/lavrin/euc-2014.git euc-2014-tsung
    cd euc-2014-tsung
    git submodule update -i
    vagrant up mim-1

Hopefully, Vagrant finishes without errors.
Before setting up another MongooseIM VM, let's bring the first server node up:

    vagrant ssh mim-1  # this will take a few minutes
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

If the environment is fine, then let's stop one of the nodes for now:

    vagrant halt mim-2


## Basic test scenario


## Troubleshooting

Vagrant might sometimes give you a "Connection timeout" error when trying
to bring a machine up or ssh to it:

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

The only way to deal with this is to halt all the machines (might not
be necessary) and kill the VirtualBox DHCP server:

    $ ps aux | grep -i vbox
    ...
    erszcz           10242   0.0  0.0  2447920   5872   ??  S     3:06PM
        0:00.07 /Applications/VirtualBox.app/Contents/MacOS/VBoxNetDHCP
        --ip-address 172.28.128.2 --lower-ip 172.28.128.3 --mac-address
        08:00:27:63:7D:35 --netmask 255.255.255.0
        --network HostInterfaceNetworking-vboxnet2 --trunk-name vboxnet2
        --trunk-type netadp --upper-ip 172.28.128.254
    $ kill 10242


## Your opinion matters

Thank you for taking part in the tutorial.
I'd really appreciate if you sent me an email with a few words
answering the questions below.
If you're busy then one word per question is enough ;)

- How did you like the tutorial?
- How difficult do you consider the tutorial (too easy/hard/just right)?
- What part of the tutorial needs improvement / more work?
