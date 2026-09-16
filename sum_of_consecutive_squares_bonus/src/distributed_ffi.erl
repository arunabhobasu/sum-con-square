-module(distributed_ffi).
-export([start_distribution/1, connect_node/1, spawn_remote/3, ping_node/1, get_nodes/0, get_hostname/0, get_node_name/0]).

%% Start distributed mode
start_distribution(NodeName) ->
    % Binary to atom
    NodeNameList = binary_to_list(NodeName),
    case net_kernel:start([list_to_atom(NodeNameList), shortnames]) of
        {ok, _} -> {ok, atom_to_binary(node(), utf8)};
        {error, {already_started, _}} -> {ok, atom_to_binary(node(), utf8)};
        Error -> Error
    end.

%% Connect to node
connect_node(NodeName) ->
    % Binary to atom
    NodeNameList = binary_to_list(NodeName),
    case net_kernel:connect_node(list_to_atom(NodeNameList)) of
        true -> {ok, connected};
        false -> {error, connection_failed};
        ignored -> {error, ignored}
    end.

%% Spawn on remote node
spawn_remote(NodeName, Module, Function) ->
    % Binary to atom
    NodeNameList = binary_to_list(NodeName),
    Node = list_to_atom(NodeNameList),
    ModuleAtom = list_to_atom(binary_to_list(Module)),
    FunctionAtom = list_to_atom(binary_to_list(Function)),
    case rpc:call(Node, ModuleAtom, FunctionAtom, []) of
        {badrpc, Reason} -> {error, Reason};
        Pid when is_pid(Pid) -> {ok, Pid};
        Result -> {ok, Result}
    end.

%% Ping node
ping_node(NodeName) ->
    % Binary to atom
    NodeNameList = binary_to_list(NodeName),
    case net_adm:ping(list_to_atom(NodeNameList)) of
        pong -> {ok, alive};
        pang -> {error, not_responding}
    end.

%% Get connected nodes
get_nodes() ->
    Nodes = nodes(),
    NodeBinaries = [atom_to_binary(Node, utf8) || Node <- Nodes],
    {ok, NodeBinaries}.

%% Get hostname
get_hostname() ->
    {ok, Hostname} = inet:gethostname(),
    {ok, list_to_binary(Hostname)}.

%% Get node name
get_node_name() ->
    atom_to_binary(node(), utf8).