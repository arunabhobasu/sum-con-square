-module(ffi).
-export([get_plain_arguments/0, get_runtime/0, get_real_time/0]).

% get command line arguments
get_plain_arguments() ->
    Args = init:get_plain_arguments(),
    % Convert charlists to binaries (strings in Gleam)
    [unicode:characters_to_binary(Arg) || Arg <- Args].

% get CPU runtime stats
get_runtime() ->
    erlang:statistics(runtime).

% get real time
get_real_time() ->
    erlang:monotonic_time(millisecond).