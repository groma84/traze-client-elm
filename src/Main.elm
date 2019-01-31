port module Main exposing (Model, Msg(..), init, main, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as JD
import Json.Encode as JE



---- PORTS ----


port receiveData : (JD.Value -> msg) -> Sub msg


port sendData : JE.Value -> Cmd msg



---- MODEL ----


type State
    = Lobby
    | Spectating String
    | Playing String


type Action
    = SpectateGameAction


actionToString : Action -> String
actionToString action =
    case action of
        SpectateGameAction ->
            "spectateGame"


type alias Game =
    { activePlayers : Int
    , name : String
    }


type GameData
    = GameData (List Game)


type TopicData
    = GameTopic GameData


type alias Model =
    { jsError : Maybe String
    , games : Maybe GameData
    , state : State
    }


init : ( Model, Cmd Msg )
init =
    ( { jsError = Nothing, games = Nothing, state = Lobby }, Cmd.none )



---- UPDATE ----


type Msg
    = NoOp
    | ReceiveMqttValue JD.Value
    | Spectate String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ReceiveMqttValue val ->
            case decodeJson val of
                Err err ->
                    ( { model | jsError = JD.errorToString err |> Just }, Cmd.none )

                Ok topicData ->
                    case topicData of
                        GameTopic gameData ->
                            ( { model | games = Just gameData }, Cmd.none )

        Spectate gameName ->
            ( { model | state = Spectating gameName }, sendData <| encodeGameName gameName )


encodeGameName : String -> JE.Value
encodeGameName gameName =
    JE.object [ ( "action", JE.string <| actionToString SpectateGameAction ), ( "name", JE.string gameName ) ]


decodeJson : JD.Value -> Result JD.Error TopicData
decodeJson =
    JD.decodeValue
        (JD.field "topic" JD.string
            |> JD.andThen decodeTopic
        )


decodeTopic : String -> JD.Decoder TopicData
decodeTopic topic =
    case topic of
        "traze/games" ->
            decodeGamePayload
                |> JD.map GameTopic

        -- traze/instanceName/players
        _ ->
            JD.fail "unhandled topic"


decodeGamePayload : JD.Decoder GameData
decodeGamePayload =
    JD.field "payload" (JD.list decodeGame)
        |> JD.map GameData


decodeGame : JD.Decoder Game
decodeGame =
    JD.map2 Game
        (JD.field "activePlayers" JD.int)
        (JD.field "name" JD.string)



---- VIEW ----


view : Model -> Html Msg
view model =
    let
        jsError =
            case model.jsError of
                Just err ->
                    div [] [ text err ]

                _ ->
                    text ""

        gamesList =
            case model.games of
                Nothing ->
                    div [] [ text "No games running" ]

                Just (GameData games) ->
                    let
                        gameRow game =
                            li []
                                [ text game.name
                                , text <| String.fromInt game.activePlayers
                                , button [ type_ "button", onClick (Spectate game.name) ] [ text "Spectate" ]
                                ]
                    in
                    ul [] (List.map gameRow games)
    in
    div []
        [ img [ src "/logo.svg" ] []
        , h1 [] [ text "Your Elm App is working!" ]
        , gamesList
        , jsError
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    receiveData ReceiveMqttValue



---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = subscriptions
        }
