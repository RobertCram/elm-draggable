module MultipleTargetsExample exposing (main)

import Draggable
import Draggable.Events exposing (onClick, onDragBy, onDragStart)
import Html exposing (Html)
import Html.Attributes
import Math.Vector2 as Vector2 exposing (Vec2, getX, getY)
import Svg exposing (Svg)
import Svg.Attributes as Attr
import Svg.Events exposing (onMouseUp)
import Svg.Keyed
import Svg.Lazy exposing (lazy)


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type alias Box =
    { id : Id
    , position : Vec2
    , clicked : Bool
    }


type alias Id =
    String


box : Id -> Vec2 -> Box
box id position =
    Box id position False


dragBoxBy : Vec2 -> Box -> Box
dragBoxBy delta box =
    { box | position = box.position |> Vector2.add delta }


toggleClicked : Box -> Box
toggleClicked box =
    { box | clicked = not box.clicked }


type alias BoxGroup =
    { uid : Int
    , movingBox : Maybe Box
    , idleBoxes : List Box
    }


emptyGroup : BoxGroup
emptyGroup =
    BoxGroup 0 Nothing []


addBox : Vec2 -> BoxGroup -> BoxGroup
addBox position ({ uid, idleBoxes } as group) =
    { group
        | idleBoxes = (box (toString uid) position) :: idleBoxes
        , uid = uid + 1
    }


boxGroup : List Vec2 -> BoxGroup
boxGroup positions =
    positions
        |> List.foldl addBox emptyGroup


allBoxes : BoxGroup -> List Box
allBoxes { movingBox, idleBoxes } =
    movingBox
        |> Maybe.map (flip (::) idleBoxes)
        |> Maybe.withDefault idleBoxes


startDragging : Id -> BoxGroup -> BoxGroup
startDragging id ({ idleBoxes, movingBox } as group) =
    let
        ( targetAsList, others ) =
            List.partition (.id >> ((==) id)) idleBoxes
    in
        { group
            | idleBoxes = others
            , movingBox = targetAsList |> List.head
        }


stopDragging : BoxGroup -> BoxGroup
stopDragging group =
    { group
        | idleBoxes = allBoxes group
        , movingBox = Nothing
    }


dragActiveBy : Vec2 -> BoxGroup -> BoxGroup
dragActiveBy delta group =
    { group | movingBox = group.movingBox |> Maybe.map (dragBoxBy delta) }


toggleBoxClicked : Id -> BoxGroup -> BoxGroup
toggleBoxClicked id group =
    let
        possiblyToggleBox box =
            if box.id == id then
                toggleClicked box
            else
                box
    in
        { group | idleBoxes = group.idleBoxes |> List.map possiblyToggleBox }


type alias Model =
    { boxGroup : BoxGroup
    , drag : Draggable.State
    }


type Msg
    = DragMsg Draggable.Msg
    | OnDragBy Vec2
    | StartDragging String
    | ToggleBoxClicked String
    | StopDragging


boxPositions : List Vec2
boxPositions =
    let
        indexToPosition =
            toFloat >> ((*) 60) >> ((+) 10) >> (Vector2.vec2 10)
    in
        List.range 0 10 |> List.map indexToPosition


init : ( Model, Cmd Msg )
init =
    ( { boxGroup = boxGroup boxPositions
      , drag = Draggable.init
      }
    , Cmd.none
    )


dragConfig : Draggable.Config Msg
dragConfig =
    Draggable.customConfig
        [ onDragBy (Draggable.deltaToFloats >> Vector2.fromTuple >> OnDragBy)
        , onDragStart StartDragging
        , onClick ToggleBoxClicked
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ boxGroup } as model) =
    case msg of
        OnDragBy delta ->
            ( { model | boxGroup = boxGroup |> dragActiveBy delta }, Cmd.none )

        StartDragging id ->
            ( { model | boxGroup = boxGroup |> startDragging id }, Cmd.none )

        StopDragging ->
            ( { model | boxGroup = boxGroup |> stopDragging }, Cmd.none )

        ToggleBoxClicked id ->
            ( { model | boxGroup = boxGroup |> toggleBoxClicked id }, Cmd.none )

        DragMsg dragMsg ->
            Draggable.update dragConfig dragMsg model


subscriptions : Model -> Sub Msg
subscriptions { drag } =
    Draggable.subscriptions DragMsg drag



-- VIEW


boxSize : Vec2
boxSize =
    Vector2.vec2 50 50


view : Model -> Html Msg
view { boxGroup } =
    Html.div
        [ Html.Attributes.style [ ( "height", "100%" ) ] ]
        [ Html.p [] [ Html.text "Drag any box around. Click it to toggle its color." ]
        , Svg.svg
            [ Attr.width "100%"
            , Attr.height "100%"
            ]
            [ background
            , boxesView boxGroup
            ]
        ]


boxesView : BoxGroup -> Svg Msg
boxesView boxGroup =
    boxGroup
        |> allBoxes
        |> List.reverse
        |> List.map boxKeyedView
        |> Svg.Keyed.node "g" []


boxKeyedView : Box -> ( String, Svg Msg )
boxKeyedView box =
    ( box.id, lazy boxView box )


boxView : Box -> Svg Msg
boxView { id, position, clicked } =
    let
        color =
            if clicked then
                "red"
            else
                "lightblue"
    in
        Svg.rect
            [ num Attr.width <| getX boxSize
            , num Attr.height <| getY boxSize
            , num Attr.x (getX position)
            , num Attr.y (getY position)
            , Attr.fill color
            , Attr.stroke "black"
            , Attr.cursor "move"
            , Draggable.mouseTrigger id DragMsg
            , onMouseUp StopDragging
            ]
            []


background : Svg msg
background =
    Svg.rect
        [ Attr.x "0"
        , Attr.y "0"
        , Attr.width "100%"
        , Attr.height "100%"
        , Attr.fill "#eee"
        ]
        []


num : (String -> Svg.Attribute msg) -> number -> Svg.Attribute msg
num attr value =
    attr (toString value)