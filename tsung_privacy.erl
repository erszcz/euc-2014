-module(tsung_privacy).
-compile([export_all]).

get_lists({_Pid, DynVars}) ->
    {ok, Id} = ts_dynvars:lookup(tsung_userid, DynVars),
    Jid = ["user", integer_to_list(Id), "@localhost/tsung"],
    ["<iq from='", Jid, "' type='get' id='getlist'>",
       "<query xmlns='jabber:iq:privacy'/>",
     "</iq>"].

set_active({_Pid, DynVars}) ->
    {ok, Id} = ts_dynvars:lookup(tsung_userid, DynVars),
    Jid = ["user", integer_to_list(Id), "@localhost/tsung"],
    {ok, Lists} = ts_dynvars:lookup(privacy_lists, DynVars),
    List = hd(Lists),
    ["<iq from='", Jid, "' type='set' id='active1'>",
       "<query xmlns='jabber:iq:privacy'>",
         "<active name='", List, "'/>",
       "</query>",
     "</iq>"].
