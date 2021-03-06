%% @author Oleg Smirnov <oleg.smirnov@gmail.com>
%% @doc MongoSQL semantic clauses
-module(mongosql_sem).

-export([compile/1, compile_all/2]).

compile_all([Token|Tail], Acc) -> 
    compile_all(Tail, [compile(Token)|Acc]);
compile_all([], Acc) -> 
    lists:reverse(Acc).

compile(Tokens) when is_list(Tokens) -> compile_all(Tokens, []);

compile({delete, Table, Where}) -> 
    {delete, compile(Table), compile(Where)};

compile({insert, Table, Fields, Values}) -> 
    {insert, compile(Table), lists:zip(compile(Fields), compile(Values))};

compile({select,_, {count}, 
	 {Table, Where,_OrderBy,_GroupBy,_Having,_Limit,_Offset}}) -> 
    {count, compile(Table), compile(Where)};

compile({select,_, Fields, 
	 {Table, Where, OrderBy,_GroupBy,_Having, Limit, Offset}}) -> 
    {find, compile(Table), compile(Where), lists:flatten([compile(OrderBy),
							  compile(Limit),
							  compile(Offset),
							  compile(Fields)])};

compile({update, Table, Assign, Where}) ->
    {update, compile(Table), compile(Where), [{<<"$set">>, compile(Assign)}]};

compile({selection, '*'}) -> [];
compile({selection, Arg}) -> [{fields, Arg}];
compile({orderby, Arg}) -> [{orderby, Arg}];
compile({limit, Arg}) -> [{limit, Arg}];
compile({offset, Arg}) -> [{offset, Arg}];
compile({assign, Arg1, Arg2}) -> {compile(Arg1), compile(Arg2)};

compile({'and', Arg1, Arg2}) -> compile(Arg1) ++ compile(Arg2);
compile({'or', Arg1, Arg2}) -> [{<<"$or">>, [compile(Arg1), compile(Arg2)]}];
compile({'not', Arg}) -> [{<<"$not">>, compile(Arg)}];

compile({'=', Arg1, Arg2}) -> [{compile(Arg1), compile(Arg2)}];
compile({'>', Arg1, Arg2}) -> [{compile(Arg1), [{gt, compile(Arg2)}]}];
compile({'<', Arg1, Arg2}) -> [{compile(Arg1), [{lt, compile(Arg2)}]}];
compile({'>=', Arg1, Arg2}) -> [{compile(Arg1), [{gte, compile(Arg2)}]}];
compile({'<=', Arg1, Arg2}) -> [{compile(Arg1), [{lte, compile(Arg2)}]}];
compile({'<>', Arg1, Arg2}) -> [{compile(Arg1), [{ne, compile(Arg2)}]}];

compile({between, Arg1, Arg2, Arg3}) -> 
    [{compile(Arg1), [{gte, compile(Arg2)}, {lte, compile(Arg3)}]}];
compile({notbetween, Arg1, Arg2, Arg3}) -> 
    [{compile(Arg1), [{gte, compile(Arg3)}, {lte, compile(Arg2)}]}];

compile({like, Arg1, Arg2}) -> 
    [{compile(Arg1), {regexp, like_to_re(compile(Arg2)), ""}}];
compile({notlike, Arg1, Arg2}) -> 
    [{compile(Arg1), {regexp, notlike_to_re(compile(Arg2)), ""}}];

compile({null, Arg}) -> [{compile(Arg), [{exists, false}]}];
compile({notnull, Arg}) -> [{compile(Arg), [{exists, true}]}];

compile({in, Arg1, Arg2}) -> [{compile(Arg1), [{in, compile(Arg2)}]}];
compile({notin, Arg1, Arg2}) -> [{compile(Arg1), [{nin, compile(Arg2)}]}];

compile({'+', Arg1, Arg2}) -> compile(Arg1) + compile(Arg2);
compile({'-', Arg1, Arg2}) -> compile(Arg1) - compile(Arg2);
compile({'*', Arg1, Arg2}) -> compile(Arg1) * compile(Arg2);
compile({'/', Arg1, Arg2}) -> compile(Arg1) / compile(Arg2);

compile(nil) -> [];

compile(Token) when is_atom(Token) -> Token;
compile(Token) when is_integer(Token) -> Token;
compile(Token) when is_bitstring(Token) -> Token;
compile(Token) when is_list(Token) -> Token;

compile(Token) -> {unknown_token, Token}.

like_to_re(Str) when is_binary(Str) ->
    Re = binary:replace(Str, <<"%">>, <<".*">>, [global]),
    <<"^", Re/binary, "$">>.
notlike_to_re(Str) when is_binary(Str) ->
    Re = binary:replace(Str, <<"%">>, <<".*">>, [global]),
    <<"^(?!(", Re/binary ,"))">>.

