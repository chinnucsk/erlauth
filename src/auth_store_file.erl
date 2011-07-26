-module(auth_store_file).

-export([get_user/2, update_user/3, add_user/1]).

-include("erlauth.hrl").

%%
%% api
%%

get_user(id, Id) ->
  file_op(fun lookup_user/3, [2, Id]);
get_user(name, Name) ->
  file_op(fun lookup_user/3, [3, Name]).

update_user(Field, UserId, Value) ->
  file_op(fun write_user_field/4, [Field, UserId, Value]).

add_user(User) ->
  file_op(fun write_user_all/2, [User]).

%%
%% internal
%%

get_store_file() ->
  code:priv_dir(erlauth) ++ "/" ++ erlauth_util:get_config(auth_file).

file_op(F,A) ->
  File = get_store_file(),
  case filelib:is_file(File) of
    true ->
      erlang:apply(F, [File | A]);
    false ->
      file:write_file(File, [])
  end.

lookup_user(File, Field, Value) ->
  {ok, Terms} = file:consult(File),
  [{users, Users}|_] = Terms,
  case lists:keyfind(Value, Field, Users) of
    {user, Id, Username, Hash, Cookie, Profile, Admin} ->
      {ok, #user{id=Id, user=Username, hash=Hash, cookie=Cookie,
                 profile=Profile, admin=Admin}};
    false ->
      {error, {user_not_found, Value}}
  end.

write_user_field(File, Field, UserId, Value) when is_atom(Field) ->
  {ok, Terms} = file:consult(File),
  [{users, Users}|_] = Terms,
  OldUser = lists:keyfind(UserId, 2, Users),
  NewUser = new_user(Field, Value, OldUser),
  NewUsers = lists:keystore(UserId, 2, Users, NewUser),
  write_users(File, NewUsers).

write_users(File, Users) ->
  Data = {users, Users},
  ok = file:write_file(File, io_lib:format("~p.~n", [Data])).

new_user(user_id, Value, OldUser) ->
  OldUser#user{id=Value};
new_user(username, Value, OldUser) ->
  OldUser#user{user=Value};
new_user(password_hash, Value, OldUser) ->
  OldUser#user{hash=Value};
new_user(cookie_hash, Value, OldUser) ->
  OldUser#user{cookie=Value};
new_user(profile, Value, OldUser) ->
  OldUser#user{profile=Value};
new_user(admin, Value, OldUser) ->
  OldUser#user{admin=Value};
new_user(Field, _Value, _OldUser) ->
  throw({invalid_field, Field}).

write_user_all(_File, _User=#user{}) ->
  ok.
