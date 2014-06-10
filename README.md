# Intro to load testing with Tsung


## Who am I?

- Radek Szymczyszyn <radoslaw.szymczyszyn@erlang-solutions.com>
- ejabberd/MongooseIM engineer
  at [Erlang Solutions Kraków](https://www.erlang-solutions.com/)
- github.com/lavrin


## What is load testing?

Types of performance testing:

- testing under a specific load - what will be an average message delivery
  time / rate on a 4 core, 64GiB RAM box with 100k users logged in and
  exchanging messages with one another?

- stress testing - what is the maximum capacity of that box?
  how many users can log in at the same time?
  what number of users makes the message delivery time unacceptable?

- spike testing - at ~9:00am people come to work; will the server be
  resilient enough to sustain the number of logins to the corporate
  IM network?

- endurance testing - the server has to run for weeks or months without
  being stopped; does it have any memory leaks or errors leading to
  resource exhaustion over extended periods of time?

All in all, [Wikipedia will tell more ;)][wiki:perf]

[wiki:perf]: http://en.wikipedia.org/wiki/Software_performance_testing


## Tsung

- GitHub: [https://github.com/processone/tsung](https://github.com/processone/tsung)
- Documentation: [http://tsung.erlang-projects.org/user_manual/index.html](http://tsung.erlang-projects.org/user_manual/index.html)


## Setting up the environment (with a good network connection)

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


## Setting up the environment (from a USB stick)

In case you're setting up the environment from a provided USB stick,
you'll still need [VirtualBox](https://www.virtualbox.org/)
and [Vagrant](https://vagrantup.com/).

Once these are installed, please clone the tutorial repository
and follow the next steps:

    git clone https://github.com/lavrin/euc-2014
    cd euc-2014
    cp -R /usb-stick-mountpoint/euc-2014/.vagrant .

Apart from `.vagrant` directory, we will need the VirtualBox VMs.
Copy them from the USB stick to `~/VirtualBox VMs`.
Preferably don't do it from the shell, as this will show no progress indicator.

Once the VMs are copied, let's verify that they start up without errors:

    cd euc-2014
    vagrant up

Please don't issue `vagrant up` before the machines are copied!
VirtualBox won't find the machine and Vagrant will try to provision it,
overwriting the data in `.vagrant` directory.


## Basic test scenario

It's time we ran a basic Tsung test.
Let's ssh into a Mongoose node in one shell and set up some trivial
monitoring to see that the users actually get connected:

    vagrant ssh mim-1
    sudo mongooseimctl start  # only if your server is not running yet
    sudo mongooseimctl debug

If the server database hasn't been seeded with user credentials yet,
then please look into `snippets.erl` in this directory for a snippet
of code doing it - we can paste it into the debug shell we've just started:

    %% Register users.
    R = fun() -> Reg = fun ejabberd_admin:register/3,
                 Numbers = [integer_to_binary(I) || I <- lists:seq(1,25000)],
                 [Reg(<<"user", No/bytes>>, <<"localhost">>, <<"pass", No/bytes>>)
                  || No <- Numbers] end.
    R().
    mnesia:table_info(passwd, size).

Again in the Erlang shell:

    ejabberd_loglevel:set(4).
    ^C^C  %% i.e. press Control-C twice

Now in Bash:

    tail -f /usr/local/lib/mongooseim/log/ejabberd.log

In a different shell window (try to have both of them on the screen at the
same time) let's ssh into a Tsung node and run a basic scenario:

    vagrant ssh tsung-1
    git clone git://github.com/lavrin/tsung-scenarios
    cd tsung-scenarios/
    mkdir ~/tsung-logs  # the next command will fail without this
    tsung -l ~/tsung-logs -f ~/tsung-scenarios/basic.xml start

You guessed right, `-l` tells Tsung to store logs into the given directory;
without it all your logs will go to `$HOME/.tsung/log`.

`-f` just tells Tsung what XML scenario to use.

Tsung will tell us that it's working with something similar to:

    Starting Tsung
    "Log directory is: /home/vagrant/tsung-logs/20140603-1520"

We should now get a log message for each established/torn down
connection in the console window where we have run `tail`:

    2014-06-03 15:39:45.707 [info] <0.535.0>@ejabberd_listener:accept:279
        (#Port<0.4574>) Accepted connection {{172,28,128,21},56051} ->
        {{172,28,128,11},5222}

    2014-06-03 15:39:47.809 [info] <0.867.0>@ejabberd_c2s:terminate:1610
        ({socket_state,gen_tcp,#Port<0.4574>,<0.866.0>}) Close session for
        user1@localhost/tsung

This tells us that Tsung has actually sent some data to MongooseIM.
How do we tell what this data was?
At the top of `tsung-scenarios/basic.xml` scenario we see:

    <tsung loglevel="debug" version="1.0" dumptraffic="true">

Thanks to `dumptraffic="true"` we'll find a dump of all the stanzas Tsung
exchanged with the server in `tsung-logs/20140603-1520/tsung.dump`.
It's convenient for verifying what exactly your scenario does or for debugging,
but **don't enable `dumptraffic` when actually load testing**
as it generates a huge amount of data.
The same goes for log level `debug`, which controls the amount of logging.

Inside the directory with the results of the test we'll also find
a number of log files:

    vagrant@tsung-1:~$ ls -1 ~/tsung-logs/20140603-1539/*.log
    tsung-logs/20140603-1539/match.log
    tsung-logs/20140603-1539/tsung0@tsung-1.log
    tsung-logs/20140603-1539/tsung_controller@tsung-1.log
    tsung-logs/20140603-1539/tsung.log

`tsung.log` contains some statistics used to generate graphs after a test
run is finished.

`match.log` contains details about glob/regex matches (or match failures)
done on replies from the server.

`tsung_controller@<...>.log` will tell us which nodes had problems
starting when load generation distribution is enabled in the scenario,
while `<nodename>.log` files contain node specific logs, e.g. crash logs
explaining why some node hasn't responded to the controller.

Apart from all the logs and statistics of a test run the result
directory also contains a copy of the scenario Tsung was run with
(in our case `tsung-logs/20140603-1520/basic.xml`).

OK, we've seen one user logging in - that's hardly a load test.
Let's make a node go down under load now!


## Stress testing a MongooseIM node until it breaks

MongooseIM is actually quite resilient,
so for the sake of making it go down under load,
let's tweak its configuration a bit (first on `mim-1`,
then on `mim-2`):

    sudo chmod ugo+w /usr/local/lib/mongooseim/etc/vm.args
    ls -l /usr/local/lib/mongooseim/etc/vm.args  # just to be sure
    sudo echo '+hms 75000' >> /usr/local/lib/mongooseim/etc/vm.args

This sets the process heap size to be ~75000 words of memory
from the beginning.

Let's make sure the server is running on both `mim-1` and `mim-2`:

    sudo mongooseimctl live

And turn on some, ekhm, _monitoring_ in the live Erlang shell:

    %% Enable "monitoring".
    F = fun(F, I) ->
                Timestamp = calendar:now_to_local_time(erlang:now()),
                NSessions = ejabberd_sm:get_vh_session_number(<<"localhost">>),
                FreeRam = "free -m | sed '2q;d' | awk '{ print $4 }'",
                io:format("~p ~p no of users: ~p, free ram: ~s",
                          [I, Timestamp, NSessions, os:cmd(FreeRam)]),
                timer:sleep(timer:seconds(2)),
                F(F, I+1)
        end.
    G = fun() -> F(F, 1) end.
    f(P).
    P = spawn(G).

Finally, on `tsung-1` let's run a scenario that should make `mim-1` crash
due to memory exhaustion:

    tsung -l ~/tsung-logs -f ~/tsung-scenarios/chat-4k.xml start

And watch as `free ram` goes lower and lower on `mim-1`:

    67 {{2014,6,6},{20,40,19}} no of users: 559, free ram: 570
    ...
    76 {{2014,6,6},{20,40,40}} no of users: 3105, free ram: 50
    ...
    82 {{2014,6,6},{20,41,3}} no of users: 3378, free ram: 48

At ~3400 logged on users and ~50MiB of free RAM Linux OOM (out of memory)
killer will kill MongooseIM.
Depending on the safety requirements, ~2000-3000 users is the upper limit
per node with this hardware setup.
Please note that without changing the per-process heap size I wasn't
able to bring the node down with ~12k users connected simultaneously.

The console will probably be broken now, let's fix it and make sure the
node is started again (with _monitoring_ - please paste the snippet again):

    reset
    sudo mongooseimctl live

Please note, that `mim-2` also reported the number of users as ~3400,
but didn't suffer - all the users were connected to `mim-1` due to the
way `chat-4k.xml` scenario had been written.


## Load testing a distributed service

Let's now perform the test again, but distribute the generated load among
both nodes of the cluster. On `tsung-1`:

    tsung -l ~/tsung-logs -f ~/tsung-scenarios/chat-4k-2servers.xml

After about a minute both nodes should report more or less
the same statistic:

    4153 {{2014,6,6},{23,7,27}} no of users: 4000, free ram: 55

In my case `mim-2` has died ~2m20s later:

    5270 {{2014,6,6},{23,9,43}} no of users: 4000, free ram: 48

`mim-1` realized that about ~30s later:

    4219 {{2014,6,6},{23,10,23}} no of users: 1992, free ram: 65

And itself went down after another ~35s:

    4236 {{2014,6,6},{23,10,59}} no of users: 1992, free ram: 49
    (mongooseim@mim-1)7> Killed

This tells us that 4000 users chatting with one another is too much
even when split more or less equally among two server nodes.
Don't forget these nodes are configured to perform worse than they could
for the sake of the demo!

If the nodes haven't crashed that would be the moment to perform some
extra measurements under sustained load,
e.g. measurement of the average response time.
Knowing that the users can connect to the service is one thing,
but knowing that the message sent from one to another doesn't take
forever to reach the addressee is another!

Unfortunately, since Tsung doesn't understand XMPP,
it falls short in this regard.


## Plotting the results

There are two tools for plotting Tsung results:
Perlish `tsung_stats.pl` and Pythonic `tsplot`.
We'll user `tsung_stats.pl`.

We now have two potentially interesting sets of results to analyze.
We might have accumulated quite a lot of result directories in `~/tsung-logs`.
Let's find the interesting ones:

    find ~/tsung-logs/ -name chat-4k.xml -o -name chat-4k-2servers.xml

Gives us:

    /home/vagrant/tsung-logs/20140606-2040/chat-4k.xml
    /home/vagrant/tsung-logs/20140607-1231/chat-4k-2servers.xml

First, let's install the dependencies I had forgotten about:

    sudo apt-get install --no-install-recommends gnuplot
    sudo apt-get install libtemplate-perl

Now, let's analyze the results of `20140606-2040/chat-4k.xml`:

    cd ~/tsung-logs/20140606-2040
    /usr/local/lib/tsung/bin/tsung_stats.pl --dygraph

`--dygraph` gives nicer (and interactive) graphs, but requires Internet
connection for viewing the report; we might drop it if the connection is poor.

Let's do the same for the other result set:

    cd ~/tsung-logs/20140607-1231
    /usr/local/lib/tsung/bin/tsung_stats.pl --dygraph

Let's start a simple HTTP server to see the results:

    cd ~/tsung-logs
    python -m SimpleHTTPServer 8080

And point the browser at `localhost:8080`.


## Scaling Tsung vertically

### Max open file descriptor limit

One of the often encountered problems with scaling up is the enigmatic
barrier of ~1000 connected users.
The server side error logs may look something like this:

    5 {{2014,6,7},{14,28,33}} no of users: 724, free ram: 482
    (mongooseim@mim-1)5> 2014-06-07 14:28:36.335 [error] <0.237.0> CRASH REPORT Process <0.237.0> with 0 neighbours exited with reason: {failed,{error,{file_error,"/usr/local/lib/mongooseim/Mnesia.mongooseim@mim-1/LATEST.LOG",emfile}}} in disk_log:reopen/3 in disk_log:do_exit/4 line 1188
    2014-06-07 14:28:36.336 [error] <0.88.0> Supervisor disk_log_sup had child disk_log started with {disk_log,istart_link,undefined} at <0.237.0> exit with reason {failed,{error,{file_error,"/usr/local/lib/mongooseim/Mnesia.mongooseim@mim-1/LATEST.LOG",emfile}}} in disk_log:reopen/3 in context child_terminated
    2014-06-07 14:28:36.341 [error] <0.26.0> File operation error: emfile. Target: ./pg2.beam. Function: get_file. Process: code_server.
    2014-06-07 14:28:36.343 [error] <0.26.0> File operation error: emfile. Target: /usr/local/lib/mongooseim/lib/kernel-3.0/ebin/pg2.beam. Function: get_file. Process: code_server.
    ...
    {"Kernel pid terminated",application_controller,"{application_terminated,mnesia,killed}"}

    Crash dump was written to: erl_crash.dump
    Kernel pid terminated (application_controller) ({application_terminated,mnesia,killed})

Essentially, that's the default operating system limit of at most 1024
open file descriptors per process.
We can see the exact limit with:

    ulimit -n

The hosts in this demo environment already have this limited raised to
300k descriptors per process, but for the sake of experiment let's lower
it again:

    ulimit -n 1024
    sudo mongooseimctl live

Run Tsung:

    tsung -l ~/tsung-logs -f ~/tsung-scenarios/chat-4k.xml start

And wait a few seconds for a few screens of errors from MongooseIM.

Of course, this limit may bite us on the Tsung side as well.
Both load generating and _attacked_ hosts need to have it altered.
To permanently set it to a different number than the default 1024
we have to modify `/etc/security/limits.conf` and login again:

    cat /etc/security/limits.conf

    ...
    vagrant         soft    nofile          300000
    vagrant         hard    nofile          300000
    mongooseim      soft    nofile          300000
    mongooseim      hard    nofile          300000

### Virtual interfaces

There's another limit we'll run into when reaching the number of ~65k
concurrent users coming from a single Tsung machine - the number
of TCP ports available per network interface.

To overcome this limit we'll have to use multiple virtual interfaces
and IP addresses for one physical NIC.

To setup/tear down an extra virtual interface on MacOS X:

    $ sudo ifconfig
    lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
        options=3<RXCSUM,TXCSUM>
        inet6 ::1 prefixlen 128
        inet 127.0.0.1 netmask 0xff000000
        inet6 fe80::1%lo0 prefixlen 64 scopeid 0x1
        nd6 options=1<PERFORMNUD>
    ...

    $ sudo ifconfig lo0 alias 127.0.1.1  # sets up the new interface/alias
    $ sudo ifconfig
    lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
        options=3<RXCSUM,TXCSUM>
        inet6 ::1 prefixlen 128
        inet 127.0.0.1 netmask 0xff000000
        inet6 fe80::1%lo0 prefixlen 64 scopeid 0x1
        inet 127.0.1.1 netmask 0xff000000  # <--- the new alias for lo0
        nd6 options=1<PERFORMNUD>
    ...

    $ sudo ifconfig lo0 -alias 127.0.1.1  # tears down an interface/alias

To do the same on Linux:

    $ sudo ifconfig
    ...
    eth1      Link encap:Ethernet  HWaddr 08:00:27:79:85:a2
              inet addr:172.28.128.21  Bcast:172.28.128.255  Mask:255.255.255.0
              UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
              RX packets:49189 errors:0 dropped:0 overruns:0 frame:0
              TX packets:73245 errors:0 dropped:0 overruns:0 carrier:0
              collisions:0 txqueuelen:1000
              RX bytes:10496764 (10.4 MB)  TX bytes:10596956 (10.5 MB)
    ...

    $ sudo ifconfig eth1:1 add 172.28.128.31
    $ sudo ifconfig
    ...
    eth1:1:0  Link encap:Ethernet  HWaddr 08:00:27:79:85:a2
              inet addr:172.28.128.31  Bcast:0.0.0.0  Mask:0.0.0.0
              UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
    ...

    $ sudo ifconfig eth1:1:0 down

In order to tell Tsung to use these interfaces we need to adjust the
scenario file. Instead of:

```xml
<clients>
    <client host="tsung-1" maxusers="200000"/>
</clients>
```

We have to use:

```xml
<clients>
    <client host="tsung-1" maxusers="200000">
        <ip value="172.28.128.21"/>
        <ip value="172.28.128.31"/>
    </client>
</clients>
```

Each IP address allows for generating up to ~65k extra simultaneous connections.


## Scaling Tsung horizontally

Adding extra IP addresses allows for generating more load from a single
Tsung node.
But what if the hardware of that node can't handle simulating more
clients?
We have to use more machines.

Prerequisites: all machines Tsung is to control must have
passwordless ssh login enabled (e.g. by exchanging public keys),
exactly the same location of Erlang and Tsung binaries and exactly
the same user (name) created in the system.

Since these VMs are created with Vagrant and Chef, the paths and the user
name will match, but we need to ssh from `tsung-1` to `tsung-2` and enable
passwordless login:

    ssh-keygen
    ssh-copy-id tsung-2
    ssh tsung-2

Making Tsung scale horizontally is a matter of adjusting the scenario file:

```xml
<clients>
    <client host="tsung-1" maxusers="200000"/>
    <client host="tsung-2" maxusers="200000"/>
</clients>
```

Then, we can run the scenario:

    tsung -l ~/tsung-logs -f ~/tsung-scenarios/scaling-horizontally.xml start

The result directory will now contain one more log file:

    ls ~/tsung-logs/20140607-1535/*.log
    /home/vagrant/tsung-logs/20140607-1535/match.log
    /home/vagrant/tsung-logs/20140607-1535/tsung0@tsung-2.log  # <-- remote tsung node
    /home/vagrant/tsung-logs/20140607-1535/tsung1@tsung-1.log
    /home/vagrant/tsung-logs/20140607-1535/tsung_controller@tsung-1.log
    /home/vagrant/tsung-logs/20140607-1535/tsung.log

And inside `tsung_controller@tsung-1.log` we should be able to find the
following lines:

    =INFO REPORT==== 7-Jun-2014::15:35:58 ===
        ts_config_server:(5:<0.73.0>) Remote beam started on node 'tsung1@tsung-1'

    =INFO REPORT==== 7-Jun-2014::15:35:58 ===
        ts_config_server:(5:<0.72.0>) Remote beam started on node 'tsung0@tsung-2'

Unfortunately, the centralized nature of Tsung controller might turn out
to be a bottleneck in cases of multiple nodes. Your mileage may vary.

Alternatively, it's possible to simply start Tsung on multiple nodes with
the same scenario without reliance on Tsung controller.
This requires more manual setup (or some scripting and ssh) and doesn't
provide consolidated results from the Tsung side,
but might be enough for stressing the server up to a certain point
and gathering statistics on the server side (e.g. using `sar`,
DTrace or SystemTap).


##

TODO: matches, embedding Erlang, calling out to Erlang


## Checklist

- Tsung is dumb, it doesn't understand XMPP
- 1024 open file descriptor limit (`ulimit -n`);
  for more than 65k outgoing connections it's necessary to use multiple
  virtual interfaces
- Tsung controller is a single point of serialization -- severe delays
  and test failures when generating massive load
- log level `debug` and `dumptraffic="true"` to see actual XMPP
  stanzas/HTTP requests
- `tsplot` and `tsung_stats.pl` for making graphs
- the paths to ssh/Erlang/Tsung and user names must match on all machines
  for distributed testing to work
- XMPP version 1.0 by default advertised by Tsung causes ejabberd/MongooseIM
  to refuse plain text authentication


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


## Your opinion matters

Thank you for taking part in the tutorial.
I'd really appreciate if you sent me an email with a few words
answering the questions below.
If you're busy then one word per question is enough ;)

- How did you like the tutorial?
- How difficult do you consider the tutorial (too easy/hard/just right)?
- What part of the tutorial needs improvement / more work?
