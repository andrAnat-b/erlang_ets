-module(user_storage).

-behaviour(gen_server).

%% API
-export([start_link/0, add_user/2, get_user/1, update_user/2, delete_user/1,
         save_to_disk/1, load_from_disk/1]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, terminate/2, code_change/3]).

%% Start the process
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% API Functions
add_user(Name, Phone) ->
    gen_server:call(?MODULE, {add_user, Name, Phone}).

get_user(Id) ->
    gen_server:call(?MODULE, {get_user, Id}).

update_user(Id, Updates) ->
    gen_server:call(?MODULE, {update_user, Id, Updates}).

delete_user(Id) ->
    gen_server:call(?MODULE, {delete_user, Id}).

save_to_disk(FileName) ->
    gen_server:call(?MODULE, {save_to_disk, FileName}).

load_from_disk(FileName) ->
    gen_server:call(?MODULE, {load_from_disk, FileName}).

init(_) ->
    %% Create the ETS table
    ets:new(user_table, [named_table, public, set]), %% якщо звернення будуть через запити до ГС то можна не робити публічною і іменованою
    {ok, []}.

handle_call({add_user, Name, Phone}, _From, State) ->
    case ets:info(user_table, size) of
        Size when is_integer(Size) ->
            Id = Size + 1, %% якщо я додам 10 юзерів а потім видалю 1ших 2х то поведінка буде не зовсім очікувана
            User = {Id, Name, Phone, 0},
            ets:insert(user_table, User),
            {reply, {ok, Id}, State};
        _ ->
            {reply, {error, "Failed to determine table size"}, State}
    end;
handle_call({get_user, Id}, _From, State) ->
    case ets:lookup(user_table, Id) of
        [User] ->
            Result = ets:update_counter(user_table, Id, {4,1}),
            io:format("Result: ~p~n", [Result]),
            {reply, {ok, User}, State};
        [] ->
            {reply, {error, not_found}, State}
    end;
handle_call({update_user,Id, NewUser}, _From, State) -> %% якщо я захочу проапдейтити юзера з ід 4 і передам NewUser = {33, ...} що буде?
    Result = ets:lookup(user_table, Id),
    io:format("Result: ~p~n", [Result]),
    case Result of
        [_User] ->
            ets:insert(user_table, NewUser),
            {reply, ok, State};
        [] ->
            {reply, {error, not_found}, State}
    end;
handle_call({delete_user, Id}, _From, State) ->
    ets:delete(user_table, Id),
    {reply, ok, State};
handle_call({save_to_disk, FileName}, _From, State) ->
    case ets:tab2file(user_table, FileName) of
        ok ->
            {reply, ok, State};
        {error, Reason} ->
            {reply, {error, Reason}, State}
    end;
handle_call({load_from_disk, FileName}, _From, State) ->
    case file:read_file_info(FileName) of
        {ok, _} ->
            ets:delete_all_objects(user_table),
            ets:delete(user_table),
            Result = ets:file2tab(FileName),
            io:format("Result: ~p~n", [Result]),
            {reply, ok, State};
        {error, enoent} ->
            {reply, {error, file_not_found}, State}
    end.

handle_cast(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
