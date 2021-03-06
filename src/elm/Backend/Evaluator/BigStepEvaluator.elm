module Backend.Evaluator.BigStepEvaluator exposing (eval, evalExpr)

import Backend.Evaluator.Helpers as Helpers
import Backend.Parser.AST exposing (..)
import Backend.Parser.Parser exposing (parse)
import Dict


eval : String -> Int
eval str =
    let
        expr =
            parse str
    in
    case expr of
        Error str ->
            Debug.log ("Cannot evaluate - " ++ str) -1

        _ ->
            case evalExpr Dict.empty expr of
                ( _, Num num ) ->
                    num

                ( _, Fun fName _ _ ) ->
                    Debug.log "Function in the last expression, returning -1" -1

                ( _, a ) ->
                    Debug.log ("evaluated expression must return Int in the end, got this: " ++ toString a) -1


evalExpr : Env -> Expr -> State
evalExpr env expr =
    case expr of
        Num num ->
            ( env, Num num )

        Var str ->
            case Dict.get str env of
                Just expr ->
                    ( env, expr )

                Nothing ->
                    Error ("Variable " ++ str ++ " not defined in env: " ++ toString env)
                        |> (,) env

        Add e1 e2 ->
            evalBinOp e1 e2 env (+)
                |> (,) env

        Mul e1 e2 ->
            evalBinOp e1 e2 env (*)
                |> (,) env

        Sub e1 e2 ->
            evalBinOp e1 e2 env (-)
                |> (,) env

        LessThan e1 e2 ->
            evalEquation e1 e2 (<) env

        BiggerThan e1 e2 ->
            evalEquation e1 e2 (>) env

        Equal e1 e2 ->
            evalEquation e1 e2 (==) env

        If eBool eThen eElse ->
            let
                ( _, vBool ) =
                    evalExpr env eBool

                ( _, vThen ) =
                    evalExpr env eThen

                ( _, vElse ) =
                    evalExpr env eElse
            in
            case vBool of
                Num bool ->
                    if Helpers.typeOf vThen /= Helpers.typeOf vElse then
                        (Error <|
                            "Type of then and else branch in if must be the same: "
                                ++ toString (Helpers.typeOf vThen)
                                ++ " : "
                                ++ toString vThen
                                ++ ", "
                                ++ toString (Helpers.typeOf vElse)
                                ++ toString vElse
                        )
                            |> (,) env
                    else if bool /= 0 then
                        vThen
                            |> (,) env
                    else
                        vElse
                            |> (,) env

                other ->
                    (Error <|
                        "Type of condition in if must be Num, but was: "
                            ++ toString (Helpers.typeOf other)
                            ++ " : "
                            ++ toString other
                    )
                        |> (,) env

        SetVar str expr ->
            let
                ( _, val ) =
                    evalExpr env expr

                newEnv =
                    Dict.insert str val env
            in
            ( newEnv, val )

        SetFun funName argNames body ->
            let
                fun =
                    Fun argNames body env

                newEnv =
                    Dict.insert funName fun env
            in
            ( newEnv, fun )

        Fun argNames body localEnv ->
            Fun argNames body localEnv
                |> (,) env

        Apply funName args ->
            case Dict.get funName env of
                Nothing ->
                    (Error <| "Function " ++ funName ++ " doesnt exist in env: " ++ toString env)
                        |> (,) env

                Just (Fun argNames body localEnv) ->
                    if List.length argNames /= List.length args then
                        (Error <| "Function " ++ funName ++ " was applied to wrong number of arguments")
                            |> (,) env
                    else
                        let
                            argVals =
                                List.map (\arg -> Tuple.second <| evalExpr env arg) args

                            namesAndVals =
                                List.map2 (,) argNames argVals

                            newLocalEnv =
                                List.foldl (\( name, val ) newEnv -> Dict.insert name val newEnv) localEnv namesAndVals
                        in
                        evalExpr newLocalEnv body

                Just a ->
                    (Error <| "Only functions can be applied to things, this was: " ++ toString a)
                        |> (,) env

        Seq exprList ->
            List.foldl (\expr ( newEnv, _ ) -> evalExpr newEnv expr) ( env, Num -1 ) exprList

        Error str ->
            ( env, Error str )


evalBinOp : Expr -> Expr -> Env -> (Int -> Int -> Int) -> Expr
evalBinOp e1 e2 env op =
    case ( evalExpr env e1, evalExpr env e2 ) of
        ( ( _, Num num1 ), ( _, Num num2 ) ) ->
            Num <| op num1 num2

        ( ( _, other1 ), ( _, other2 ) ) ->
            Error <| "Both expressions in " ++ toString op ++ "-expression must be int: " ++ toString other1 ++ ", " ++ toString other2


evalEquation : Expr -> Expr -> (Int -> Int -> Bool) -> Env -> State
evalEquation e1 e2 op env =
    evalBinOp e1
        e2
        env
        (\v1 v2 ->
            if op v1 v2 then
                1
            else
                0
        )
        |> (,) env
