module Parser.SimpleParser exposing (parse)

import Parser.ParserHelper exposing (..)
import SimpleAST exposing (..)
import Stack exposing (..)
import Tokenizer exposing (tokenize)


parse : String -> Expr
parse str =
    let
        exprs =
            str
                |> String.split ";"
                |> List.filter (not << String.isEmpty)
                -- filter: remove last empty str if semicolon in the end
                |> List.map (parseLine << tokenize << String.toList)
    in
    case exprs of
        [ expr ] ->
            expr

        xs ->
            Seq exprs


parseLine : List String -> Expr
parseLine =
    uncurry buildAST << parseExpr Stack.initialise Stack.initialise


parseExpr : ExprStack -> OpStack -> List String -> ( ExprStack, OpStack )
parseExpr exprStack opStack strList =
    case strList of
        "+" :: rest ->
            parseBinOp exprStack opStack Add PAdd rest

        -- "-" -> Not supporting unary minus
        "*" :: rest ->
            parseBinOp exprStack opStack Mul PMul rest

        "-" :: rest ->
            parseBinOp exprStack opStack Sub PSub rest

        "<" :: rest ->
            parseBinOp exprStack opStack LessThan PLessThan rest

        "(" :: rest ->
            let
                ( insideParens, rest1 ) =
                    readTil ")" rest

                parensExpr =
                    parseLine insideParens
            in
            parseExpr (Stack.push parensExpr exprStack) opStack rest1

        "if" :: rest ->
            let
                ( condStrs, rest1 ) =
                    readTil "then" rest

                ( thenStrs, rest2 ) =
                    readTil "else" rest1

                condExpr =
                    parseExpr exprStack opStack condStrs
                        |> uncurry buildAST
            in
            parseExpr exprStack (push (IfOp <| If condExpr) opStack) (thenStrs ++ rest2)

        {- function f a b c = something -}
        "function" :: fName :: rest ->
            let
                ( argNames, rest1 ) =
                    readTil "=" rest
            in
            parseExpr exprStack (push (SetOp <| SetFun fName argNames) opStack) rest1

        "set" :: vName :: "=" :: rest ->
            parseExpr exprStack (push (SetOp <| SetVar vName) opStack) rest

        "set" :: _ ->
            ( push (Error "syntax error for set-variable") exprStack, opStack )

        {- Lambda -}
        "\\" :: lamVar :: "->" :: rest ->
            ( exprStack, opStack )

        fName :: "(" :: rest ->
            let
                ( argStrs, rest1 ) =
                    readTil ")" rest

                exprArgs =
                    List.map
                        (\argStr ->
                            case String.toInt argStr of
                                Ok num ->
                                    Num num

                                Err _ ->
                                    Var argStr
                        )
                        argStrs
            in
            parseExpr (push (Apply fName exprArgs) exprStack) opStack rest1

        a :: rest ->
            case String.toInt a of
                Ok num ->
                    parseExpr (push (Num num) exprStack) opStack rest

                Err _ ->
                    parseExpr (push (Var a) exprStack) opStack rest

        [] ->
            ( exprStack, opStack )


parseBinOp : ExprStack -> OpStack -> (Expr -> Expr -> Expr) -> PrecedenceType -> List String -> ( ExprStack, OpStack )
parseBinOp exprStack opStack op pType rest =
    let
        nextOpType =
            lookaheadOp rest

        ( exprStackRest, opStackRest ) =
            parseExpr Stack.initialise Stack.initialise rest

        ( mLastExpr, exprStack1 ) =
            pop exprStack

        ( mNextExpr, exprStackRest1 ) =
            popBottom exprStackRest
    in
    if not (hasHigherPrecedence nextOpType pType) then
        let
            newExpr =
                applyBinOp op mLastExpr mNextExpr

            mergedExprStack =
                Stack.mergeStacks (Stack.push newExpr exprStack1) exprStackRest1

            mergedOpStack =
                Stack.mergeStacks opStack opStackRest
        in
        ( mergedExprStack, mergedOpStack )
    else
        parseExpr exprStack (Stack.push (BinOp op) opStack) rest


buildAST : ExprStack -> OpStack -> Expr
buildAST exprStack opStack =
    let
        ( mLastExpr, exprStack1 ) =
            Stack.pop exprStack

        ( mSndLastExpr, exprStack2 ) =
            Stack.pop exprStack1

        ( mThdLastExpr, exprStack3 ) =
            Stack.pop exprStack2
    in
    case mLastExpr of
        Just (Error str) ->
            Error <| "Parse error: " ++ str

        _ ->
            case Stack.pop opStack of
                ( Just (BinOp op), opStack1 ) ->
                    let
                        newExprStack =
                            Stack.push (applyBinOp op mSndLastExpr mLastExpr) exprStack2
                    in
                    buildAST newExprStack opStack1

                ( Just (UnOp op), opStack1 ) ->
                    let
                        newExprStack =
                            Stack.push (applyUnOp op mLastExpr) exprStack1
                    in
                    buildAST newExprStack opStack1

                ( Just (IfOp op), opStack1 ) ->
                    let
                        newExprStack =
                            Stack.push (applyBinOp op mSndLastExpr mLastExpr) exprStack2
                    in
                    buildAST newExprStack opStack1

                ( Just (SetOp op), opStack1 ) ->
                    case mLastExpr of
                        Just lastExpr ->
                            let
                                newExprStack =
                                    Stack.push (op lastExpr) exprStack1
                            in
                            buildAST newExprStack opStack1

                        Nothing ->
                            Error "Expression stack is empty when trying to make a Set-node"

                ( Nothing, _ ) ->
                    case Stack.top exprStack of
                        Just expr ->
                            expr

                        Nothing ->
                            Error "Expression stack was empty at the end, have nothing to return"


applyBinOp : (Expr -> Expr -> Expr) -> Maybe Expr -> Maybe Expr -> Expr
applyBinOp op mLeft mRight =
    case ( mLeft, mRight ) of
        ( Just left, Just right ) ->
            op left right

        ( a, b ) ->
            Error <| "Binary operator " ++ toString op ++ " needs two arguments, but got: (" ++ toString a ++ ", " ++ toString b


applyUnOp : (Expr -> Expr) -> Maybe Expr -> Expr
applyUnOp op mExpr =
    case mExpr of
        Just expr ->
            op expr

        Nothing ->
            Error <| "Unary operator " ++ toString op ++ " needs one argument, but arguments was Nothing."
