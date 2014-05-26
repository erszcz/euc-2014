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
- Tsung controller is a single point of serialization -- delays
- debug log level and dump traffic
- scripts for making graphs
- the paths to ssh/Tsung must match on all machines for distributed
  testing to work
- XMPP version 1.0 for ejabberd/MongooseIM causes the server
  to refuse plaintext authentication


## Steps

### Intro

To start the first virtual machine:

    git clone euc-2014-tsung
    cd euc-2014-tsung
    git submodule update -i
    vagrant up
