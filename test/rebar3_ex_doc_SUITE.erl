-module(rebar3_ex_doc_SUITE).

-compile(export_all).
-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

all() ->
    [
        generate_docs,
        generate_docs_with_current_app_set,
        generate_docs_with_bad_config,
        format_errors
    ].

init_per_suite(Config) ->
    {ok, Cwd} = file:get_cwd(),
    file:set_cwd("../../../.."),
    erlang:display(file:get_cwd()),
    {ok, _} = rebar_utils:sh("mix do deps.get, escript.build", [
        {use_stdout, true}, {return_on_error, true}
    ]),
    file:set_cwd(Cwd),
    Config.

end_per_suite(Config) ->
    Config.

generate_docs(Config) ->
    StubConfig = #{
        app_src => #{version => "0.1.0"},
        dir => data_dir(Config),
        name => "default_docs",
        config =>
            {ex_doc, [
                {source_url, <<"https://github.com/eh/eh">>},
                {extras, [<<"README.md">>, <<"LICENSE">>]},
                {main, <<"readme">>},
                {proglang, erlang}
            ]}
    },
    {State, App} = make_stub(StubConfig),
    ok = make_readme(App),
    ok = make_license(App),
    {ok, _} = rebar3_ex_doc:do(State).

generate_docs_with_current_app_set(Config) ->
    StubConfig = #{
        app_src => #{version => "0.1.0"},
        dir => data_dir(Config),
        name => "default_docs",
        config =>
            {ex_doc, [
                {source_url, <<"https://github.com/eh/eh">>},
                {extras, [<<"README.md">>, <<"LICENSE">>]},
                {main, <<"readme">>},
                {proglang, erlang}
            ]}
    },
    {State, App} = make_stub(StubConfig),
    State1 = rebar_state:current_app(State, App),
    ok = make_readme(App),
    ok = make_license(App),
    {ok, _} = rebar3_ex_doc:do(State1).

generate_docs_with_bad_config(Config) ->
    StubConfig = #{
        app_src => #{version => "0.1.0"},
        dir => data_dir(Config),
        name => "default_docs1",
        config =>
            {ex_doc, [
                {source_url, "https://github.com/eh/eh"},
                {extras, ["README.md", "LICENSE"]},
                {main, "readme"},
                {proglang, erlang}
            ]}
    },
    {State, App} = make_stub(StubConfig),
    ok = make_readme(App),
    ok = make_license(App),
    ?assertError({error, {rebar3_ex_doc, {ex_doc, _}}}, rebar3_ex_doc:do(State)).

format_errors(_) ->
    Err = "The app 'foo' specified was not found.",
    ?assertEqual(Err, rebar3_ex_doc:format_error({app_not_found, foo})),

    Err1 =
        "An unknown error occured generating doc chunks with edoc. Run with DIAGNOSTICS=1 for more details.",
    ?assertEqual(Err1, rebar3_ex_doc:format_error({gen_chunks, some_error})),

    Err2 = "An unknown error occured compiling apps. Run with DIAGNOSTICS=1 for more details.",
    ?assertEqual(Err2, rebar3_ex_doc:format_error({compile, some_error})),

    Err3 =
        "An unknown error occured generating docs config. Run with DIAGNOSTICS=1 for more details.",
    ?assertEqual(Err3, rebar3_ex_doc:format_error({write_config, some_error})),

    Err4 = "",
    ?assertEqual(Err4, rebar3_ex_doc:format_error({ex_doc, abort})),

    Err5 = "An unknown error has occured. Run with DIAGNOSTICS=1 for more details.",
    ?assertEqual(Err5, rebar3_ex_doc:format_error({eh, some_error})).

make_readme(App) ->
    file:write_file(filename:join(rebar_app_info:dir(App), "README.md"), <<"# README">>).

make_license(App) ->
    file:write_file(filename:join(rebar_app_info:dir(App), "LICENSE"), <<"LICENSE">>).

make_stub(#{name := Name, dir := Dir} = StubConfig) ->
    AppDir = filename:join(Dir, [Name]),
    mkdir_p(AppDir),
    _SrcFile = write_src_file(AppDir, StubConfig),
    _AppSrcFile = write_app_src_file(AppDir, StubConfig),
    _ConfigFile = write_config_file(AppDir, StubConfig),
    State = init_state(AppDir, StubConfig),
    [App] = rebar_state:project_apps(State),
    {ok, State1} = rebar_prv_edoc:init(State),
    {ok, State2} = rebar_prv_compile:init(State1),
    {State2, App}.

init_state(Dir, Config) ->
    State = rebar_state(Dir, Config),
    LibDirs = rebar_dir:lib_dirs(State),
    rebar_app_discover:do(State, LibDirs).

write_src_file(Dir, #{name := Name}) ->
    Erl = filename:join([Dir, "src/", Name ++ ".erl"]),
    ok = filelib:ensure_dir(Erl),
    ok = ec_file:write(Erl, erl_src_file(Name)).

write_app_src_file(Dir, #{name := Name, app_src := #{version := Vsn}}) ->
    Filename = filename:join([Dir, "src", Name ++ ".app.src"]),
    ok = filelib:ensure_dir(Filename),
    ok = ec_file:write_term(Filename, get_app_metadata(Name, Vsn)).

write_config_file(Dir, #{config := Config}) ->
    Filename = filename:join([Dir, "rebar.config"]),
    ok = filelib:ensure_dir(Filename),
    ok = ec_file:write_term(Filename, Config).

get_app_metadata(Name, Vsn) ->
    {application, erlang:list_to_atom(Name), [
        {description, "An OTP application"},
        {vsn, Vsn},
        {registered, []},
        {applications, []},
        {env, []},
        {modules, []},
        {licenses, ["Apache 2.0"]},
        {links, []}
    ]}.

erl_src_file(Name) ->
    io_lib:format(
        "-module('~s').\n"
        "-export([main/0]).\n"
        "main() -> ok.\n",
        [filename:basename(Name, ".erl")]
    ).

mkdir_p(Path) ->
    DirName = filename:join([filename:absname(Path), "tmp"]),
    filelib:ensure_dir(DirName).

rebar_state(AppsDir, #{config := CustomConfig}) ->
    file:set_cwd(AppsDir),
    Config = [
        {dir, AppsDir},
        {root_dir, AppsDir},
        {base_dir, filename:join([AppsDir, "_build"])},
        {command_parsed_args, []},
        {resources, []},
        {hex, [{doc, #{provider => ex_doc}}]}
    ],
    Config1 = lists:merge(Config, [CustomConfig]),
    State = rebar_state:new(Config1),
    State.

data_dir(Config) -> ?config(priv_dir, Config).