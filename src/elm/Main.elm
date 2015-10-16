import App exposing (init, update, view)
import Counter exposing (init, update, view)
import CustomStartApp
import Effects exposing (Never)
import RouteHash
import Task exposing (Task)

app =
  StartApp.start
    { init = init
    , update = update
    , view = view
    , inputs = []
    }


main =
  app.html

-- Ports

port tasks : Signal (Task.Task Never ())
port tasks =
  app.tasks

port routeTasks : Signal (Task () ())
port routeTasks =
  RouteHash.start
    { prefix = RouteHash.defaultPrefix
    , address = app.address
    , models = app.model
    , delta2update = App.delta2update
    , location2action = App.location2action
    }
