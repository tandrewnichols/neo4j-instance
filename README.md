Neo4J Instance
==============

This bash script was mainly written to manage different instances of neo4j on a development system.  I decided to make 
it available for people who find themselves in the same boat.  It doesn't require much, since it is written totally in 
bash script.  Make sure you have wget, or curl installed and you should be all set.

###INSTALLATION

There are several ways to install this script. You can either clone this repository and symlink `neo4j-instance.sh` to somewhere in your PATH, or, if you don't want the whole repo, just run

```bash
curl -L https://raw.githubusercontent.com/tandrewnichols/neo4j-instance/master/neo4j-instance.sh > ~/bin/neo4j-instance && chmod +x ~/bin/neo4j-instance
```

Make sure ~/bin is in your PATH (or put it somewhere else that is).

###USAGE
```bash
  help                           outputs this document
  create [option]                create a new database instance
    options:
          -d <db name>           sets the name of the neo4j instance
          -t <neo4j type>        sets the neo4j type (community | enterprise)
          -v <neo4j version>     sets neo4j version (default: 2.1.6)
  rename-db <port> <db name>     renames the db neo4j instance
  start <port>                   starts a neo4j instance
  stop <port>                    stops a neo4j instance
  destroy <port>                 destroys a database instance
  list                           list the different databases,
                                 with their ports and their status
  plugin list [port]             list the available plugins for neo4j
  plugin install <alias> <port>  installs a plugin
  plugin remove <alias> <port>   remove a plugin
```

###NEW STUFF

I have found some really useful plugins, that are created by a company called [GraphAware](www.graphaware.com).  I am 
using about two of their plugins, but I am giving a full listing of what they offer.  I am using their TimeTree in 
everything I do now.

###MAC USAGE

Mac is (notoriously) pinned to a previous (read: old) version of bash that doesn't support associative arrays, so a Mac-friendly version of this script that doesn't use them is also provided. Just use `neo4j-instance-mac.sh` instead of `neo4j-instance.sh`.
