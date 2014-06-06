%% Enable "monitoring".
F = fun(F, I) ->
            Timestamp = calendar:now_to_local_time(erlang:now()),
            NSessions = ejabberd_sm:get_vh_session_number(<<"localhost">>),
            FreeRam = "free -m | sed '2q;d' | awk '{ print $4 }'",
            io:format("~p ~p no of users: ~p, free ram: ~s",
                      [I, Timestamp, NSessions, os:cmd(FreeRam)]),
            timer:sleep(timer:seconds(2)),
            F(F, I+1)
    end.
G = fun() -> F(F, 1) end.
f(P).
P = spawn(G).

%% Disable "monitoring".
exit(P, kill).

%% Show running MongooseIM nodes.
mnesia:system_info(running_db_nodes).

%% Register users.
R = fun() -> Reg = fun ejabberd_admin:register/3,
             Numbers = [integer_to_binary(I) || I <- lists:seq(1,25000)],
             [Reg(<<"user", No/bytes>>, <<"localhost">>, <<"pass", No/bytes>>)
              || No <- Numbers] end.
R().
mnesia:table_info(passwd, size).
