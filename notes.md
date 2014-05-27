# Plan


## Intro

- who am I?
- what is load testing?


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
- debug log level and dump traffic to see actual XMPP stanzas
- scripts for making graphs
- the paths to ssh/erlang/Tsung must match on all machines for distributed
  testing to work
- XMPP version 1.0 by default advertised by Tsung causes ejabberd/MongooseIM
  to refuse plaintext authentication


## Steps

### Intro

To create and provision the virtual machines:

    git clone euc-2014-tsung
    cd euc-2014-tsung
    git submodule update -i
    vagrant up
    vagrant ssh [mim-1 | mim-2 | tsung-1 | tsung-2]
    . otp/17.0/activate
