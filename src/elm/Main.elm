module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (keyCode, on, onClick, onInput)
import Json.Decode as Json
import Parser.SimpleParser exposing (parse)
import SimpleAST exposing (Expr(..))
import Visualizer.Node as Node


type Msg
    = NoOp
    | UpdateString String
    | ParseString
    | KeyDown Int


type alias Model =
    { ast : Maybe Expr
    , textInput : Maybe String
    }


main : Program Never Model Msg
main =
    Html.beginnerProgram { model = model, view = view, update = update }


model : Model
model =
    { ast = Nothing
    , textInput = Nothing
    }


view : Model -> Html Msg
view model =
    div [ class "page" ]
        [ viewContent model ]


viewContent : Model -> Html Msg
viewContent model =
    div [ class "content" ]
        [ div [ class "top-container" ]
            [ [ textInput
              , button [ class "button btn", onClick ParseString ] [ text "Parse" ]
              ]
                |> div [ class "input-container" ]
            , h3 [ style [ ( "color", "white" ) ] ] [ text "Expr: " ]
            , [ astToString model.ast
                    |> text
              ]
                |> div [ style [ ( "color", "white" ) ] ]
            ]
        , [ Node.drawTree model.ast ]
            |> div [ class "tree-container" ]
        ]


textInput : Html Msg
textInput =
    input
        [ class "input"
        , placeholder "Skriv inn et uttrykk"
        , onInput UpdateString
        , onKeyDown KeyDown
        ]
        []


update : Msg -> Model -> Model
update msg model =
    case msg of
        NoOp ->
            model

        UpdateString inp ->
            { model
                | textInput =
                    if String.isEmpty inp then
                        Nothing
                    else
                        Just inp
            }

        ParseString ->
            parseString model

        KeyDown key ->
            if key == 13 then
                parseString model
            else
                model


parseString : Model -> Model
parseString model =
    let
        newAST =
            Maybe.map parse model.textInput
    in
    { model | ast = newAST }



--<| eval "function foo x y = x + y; foo (3,4);"
-- HELPERS


astToString : Maybe Expr -> String
astToString mAST =
    case mAST of
        Just ast ->
            toString ast

        Nothing ->
            "..."


onKeyDown : (Int -> Msg) -> Attribute Msg
onKeyDown tagger =
    on "keydown" (Json.map tagger keyCode)