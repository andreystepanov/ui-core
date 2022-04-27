module UI.PageContent exposing
    ( PageContent
    , PageHeading
    , empty
    , oneColumn
    , threeColumns
    , twoColumns
    , view
    , withPageHeading
    )

import Html exposing (Html, div, h1, header, p, section, text)
import Html.Attributes exposing (class)
import UI.Icon as Icon exposing (Icon)


type alias PageHeading msg =
    { icon : Maybe (Icon msg)
    , heading : String
    , description : Maybe String
    }


type PageContent msg
    = PageContent
        { heading : Maybe (PageHeading msg)
        , content : List (List (Html msg))
        }



-- CREATE


empty : PageContent msg
empty =
    PageContent { heading = Nothing, content = [] }


{-| Create a page content with a single column and no heading
-}
oneColumn : List (Html msg) -> PageContent msg
oneColumn rows =
    PageContent { heading = Nothing, content = [ rows ] }


{-| Create a page content with 2 columns and no heading
-}
twoColumns : ( List (Html msg), List (Html msg) ) -> PageContent msg
twoColumns ( one, two ) =
    PageContent { heading = Nothing, content = [ one, two ] }


{-| Create a page content with 3 columns and no heading
-}
threeColumns : ( List (Html msg), List (Html msg), List (Html msg) ) -> PageContent msg
threeColumns ( one, two, three ) =
    PageContent { heading = Nothing, content = [ one, two, three ] }



-- MODIFY


{-| Set a PageHeading
-}
withPageHeading : PageHeading msg -> PageContent msg -> PageContent msg
withPageHeading pageHeading (PageContent cfg) =
    PageContent { cfg | heading = Just pageHeading }



-- VIEW


viewPageHeading : PageHeading msg -> Html msg
viewPageHeading { icon, heading, description } =
    let
        items =
            case ( icon, description ) of
                ( Nothing, Nothing ) ->
                    [ h1 [] [ text heading ] ]

                ( Nothing, Just d ) ->
                    [ div [ class "text" ]
                        [ h1 [] [ text heading ]
                        , p [ class "description" ] [ text d ]
                        ]
                    ]

                ( Just i, Nothing ) ->
                    [ div [ class "icon-badge" ] [ Icon.view i ]
                    , h1 [] [ text heading ]
                    ]

                ( Just i, Just d ) ->
                    [ div [ class "icon-badge" ] [ Icon.view i ]
                    , div [ class "text" ]
                        [ h1 [] [ text heading ]
                        , p [ class "description" ] [ text d ]
                        ]
                    ]
    in
    header [ class "page-heading" ] items


viewColumn : List (Html msg) -> Html msg
viewColumn column =
    section [ class "column" ] column


viewColumns : List (List (Html msg)) -> Html msg
viewColumns columns =
    section [ class "columns" ] (List.map viewColumn columns)


view : PageContent msg -> Html msg
view (PageContent { heading, content }) =
    let
        items =
            case heading of
                Just h ->
                    [ viewPageHeading h, viewColumns content ]

                Nothing ->
                    [ viewColumns content ]
    in
    section [ class "page-content" ] items
