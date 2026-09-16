% FFI for system interfaces
-module(ffi).
-export([get_plain_arguments/0, get_runtime/0, get_real_time/0]).

% Get CLI args
get_plain_arguments() ->
    Args = init:get_plain_arguments(),
    % To binaries
    [unicode:characters_to_binary(Arg) || Arg <- Args].

% Get runtime stats
get_runtime() ->
    erlang:statistics(runtime).

% Get precise time
get_real_time() ->
    erlang:monotonic_time(millisecond).