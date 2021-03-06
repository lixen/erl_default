-module(user_compile).

-export([c/1, c/2, src/1, smc/0, sm/0]).

-include_lib("kernel/include/file.hrl").


c(M) ->
    c(M, []).

c(M, Opts) ->
    case shellc(M, Opts) of
        error ->
            try src(M) of
                S -> shellc(S, Opts ++ include(M) ++
                                [
                                 {outdir,filename:dirname(
                                           code:which(M))}])
            catch error: E -> E
            end;
        O -> O
    end.

%% Helps with rebarified projects.
include(M) ->
    [{i, "/" ++ string:join(P, "/")++"/"} || P <- do_include(M)].

do_include(M) ->
    Path = string:tokens(filename:dirname(src(M)), "/"),
    try lists:sublist(Path, length(Path)-2, 3) of
        ["deps", _, "ebin"] ->
            [lists:sublist(Path, 1, length(Path)-2)];
        _ -> [lists:sublist(Path, 1, length(Path)-1),
              lists:sublist(Path, 1, length(Path)-1) ++ ["deps"]]
    catch _:_ ->
            [lists:sublist(Path, 1, length(Path)-1),
             lists:sublist(Path, 1, length(Path)-1) ++ ["deps"]]
    end.

shellc(M, Opts) ->
    shell_default:c(M, Opts++[debug_info]).

src(Module) ->
    proplists:get_value(source,
                        proplists:get_value(compile,
                                            Module:module_info())).

smc() ->
    [begin c(M), c:l(M) end || M <- sm()].

sm() ->
    [M || {M, _} <- code:all_loaded(), source_modified(M)].

source_modified(Module) ->
    case code:is_loaded(Module) of
        {file, preloaded} ->
            false;
        {file, _Path} ->
            CompileOpts = proplists:get_value(compile, Module:module_info()),
            Src = proplists:get_value(source, CompileOpts),
            case {file:read_file_info(Src),
                  file:read_file_info(code:which(Module))}  of
                {{ok, #file_info{mtime = SrcMTime}},
                 {ok, #file_info{mtime = BeamMTime}}} ->
                    BeamMTime < SrcMTime;
                _ ->
                    false
            end;
        _ ->
            false
    end.
