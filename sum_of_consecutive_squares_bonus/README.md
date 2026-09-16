# Distributed Solution (Uses EPMD to connect to multiple nodes)

## Local only mode syntax : gleam run -- <n> <k>
## Distributed mode syntax :  gleam run -- --distributed <n> <k> <local_node> <remote_nodes...>

## Assumptions : 
they are on same subnet
firewall is disabled or configured to allow EPMD port connections on TCP 4369

## Starting Distributed Mode -
### Step 1: Start Remote Worker Nodes

**On Worker Machine 1:**
gleam build
erl -sname worker1@testnode2 -setcookie USMZATWGOJNSTYXFVMEW

**On Worker Machine 2:**
gleam build
erl -sname worker2@testnode3 -setcookie USMZATWGOJNSTYXFVMEW


### Step 2: Start Main Coordinator Node

**On Main Machine:**
gleam build
erl -setcookie USMZATWGOJNSTYXFVMEW -sname main@testnode
press ctrl+c twice to escape erlang shell with epmd running behind
$env:ERL_FLAGS = "-setcookie USMZATWGOJNSTYXFVMEW"
gleam run -- --distributed 100 10 main@testnode worker1@testnode2 worker2@testnode3

