module Login where

import Base64 exposing (encode)
import Config exposing (backendUrl)
import Effects exposing (Effects, Never)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onSubmit, targetValue)
import Http
import Json.Encode as JE exposing (string, Value)
import Json.Decode as JD exposing ((:=))
import Storage exposing (..)
import String exposing (length)
import Task


import Debug


-- MODEL

type alias AccessToken = String

type alias LoginForm =
  { name: String
  ,  pass : String
  }

type Status =
  Init
  | Fetching
  | Fetched
  | HttpError Http.Error

type alias Model =
  { accessToken: AccessToken
  , loginForm : LoginForm
  , status : Status
  , hasAccessTokenInStorage : Bool
  }

initialModel : Model
initialModel =
  { accessToken = ""
  , loginForm = LoginForm "demo" "1234"
  , status = Init
  -- We start by assuming there's already an access token it the localStorage.
  -- While this property is set to True, the login form will not appear.
  , hasAccessTokenInStorage = True
  }


init : (Model, Effects Action)
init =
  ( initialModel
  -- Try to get an existing access token.
  , getInputFromStorage
  )


-- UPDATE

type Action
  = UpdateName String
  | UpdatePass String
  | SubmitForm
  | UpdateAccessTokenFromServer (Result Http.Error AccessToken)

  -- Storage
  | GetStorage (Result String ())
  | SetStorage String
  | UpdateAccessTokenFromStorage (Result String String)


update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    UpdateName name ->
      let
        loginForm = model.loginForm
        updatedLoginForm = { loginForm | name <- name }
      in
      ({model | loginForm <- updatedLoginForm }, Effects.none)

    UpdatePass pass ->
      let
        loginForm = model.loginForm
        updatedLoginForm = { loginForm | pass <- pass }
      in
      ({model | loginForm <- updatedLoginForm }, Effects.none)

    SubmitForm ->
      let
        url : String
        url = Config.backendUrl ++ "/api/login-token"

        credentials : String
        credentials = encodeCredentials(model.loginForm.name, model.loginForm.pass)
      in
        if model.status == Fetching || model.status == Fetched
          then
            (model, Effects.none)
          else
            ( { model | status <- Fetching}
            , getJson url credentials
            )

    UpdateAccessTokenFromServer result ->
      let
        model'  = { model | status <- Fetched}
      in
        case result of
          Ok token ->
            ( { model' | accessToken <- token }
            , sendInputToStorage token
            )
          Err msg ->
            ( { model' | status <- HttpError msg }
            , Effects.none
            )


    GetStorage result ->
      case result of
        Ok token ->
          (model, getInputFromStorage)
        Err err ->
          (model, Effects.none)


    SetStorage token ->
      -- Don't update the model here, instead after this action is done, the
      -- effect should call another action to update the model.
      ( model, sendInputToStorage token)

    UpdateAccessTokenFromStorage result ->
      case result of
        Ok token ->
          ( { model | accessToken <- token }
          , Effects.none
          )
        Err err ->
          -- There was no access token in the storage, so show the login form
          ( { model | hasAccessTokenInStorage <- False }
          , Effects.none
          )


sendInputToStorage : String -> Effects Action
sendInputToStorage s =
  Storage.setItem "access_token" (JE.string s)
    |> Task.toResult
    |> Task.map GetStorage
    |> Effects.task

getInputFromStorage : Effects Action
getInputFromStorage =
  Storage.getItem "access_token" JD.string
    |> Task.toResult
    |> Task.map UpdateAccessTokenFromStorage
    |> Effects.task



-- VIEW

(=>) = (,)

view : Signal.Address Action -> Model -> Html
view address model =
  -- <a class="btn btn-block btn-social btn-lg btn-github" ng-show="githubClientId" ng-href="https://github.com/login/oauth/authorize?client_id={{ githubClientId }}&scope=user:email,read:org,{{ githubPrivateAccess ? 'repo' : 'public_repo'}}">
  --   <i class="fa fa-github"></i> Sign in with GitHub
  -- </a>
  let
    baseUrl =
      "https://github.com/login/oauth/authorize?client_id=" ++ model.githubClientId ++ "&scope=user:email,read:org,"

    url =
      if model.githubPrivateAccess
        then baseUrl ++ "repo"
        else baseUrl ++ "public_repo"
  in
    div
      []
      [ a
          [href url, class "btn btn-block btn-social btn-lg btn-github"]
          [ i [ class="fa fa-github"] [text "Sign in with GitHub" ]
      ]

-- EFFECTS

encodeCredentials : (String, String) -> String
encodeCredentials (name, pass) =
  let
     base64 = Base64.encode(name ++ ":" ++ pass)
  in
    case base64 of
     Ok result -> result
     Err err -> ""

getJson : String -> String -> Effects Action
getJson url credentials =
  Http.send Http.defaultSettings
    { verb = "GET"
    , headers = [("Authorization", "Basic " ++ credentials)]
    , url = url
    , body = Http.empty
    }
    |> Http.fromJson decodeAccessToken
    |> Task.toResult
    |> Task.map UpdateAccessTokenFromServer
    |> Effects.task


decodeAccessToken : JD.Decoder AccessToken
decodeAccessToken =
  JD.at ["access_token"] <| JD.string
