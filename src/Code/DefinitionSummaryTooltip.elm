module Code.DefinitionSummaryTooltip exposing (Model, Msg, init, tooltipConfig, update)

import Code.CodebaseApi as CodebaseApi
import Code.Config exposing (Config)
import Code.Definition.AbilityConstructor exposing (AbilityConstructor(..), AbilityConstructorSummary)
import Code.Definition.DataConstructor as DataConstructor exposing (DataConstructor(..), DataConstructorSummary)
import Code.Definition.Reference as Reference exposing (Reference(..))
import Code.Definition.Term as Term exposing (Term(..), TermSummary, termSignatureSyntax)
import Code.Definition.Type as Type exposing (Type(..), TypeSummary, typeSourceSyntax)
import Code.FullyQualifiedName as FQN
import Code.Hash as Hash
import Code.Syntax as Syntax
import Dict exposing (Dict)
import Html exposing (div, span, text)
import Html.Attributes exposing (class)
import Json.Decode as Decode exposing (at, field)
import Lib.HttpApi as HttpApi exposing (ApiRequest, HttpResult)
import Lib.Util as Util
import RemoteData exposing (RemoteData(..), WebData)
import UI.Placeholder as Placeholder
import UI.Tooltip as Tooltip exposing (Tooltip)



-- MODEL


type DefinitionSummary
    = TermHover TermSummary
    | TypeHover TypeSummary
    | DataConstructorHover DataConstructorSummary
    | AbilityConstructorHover AbilityConstructorSummary


type alias Model =
    { activeTooltip : Maybe ( Reference, WebData DefinitionSummary )
    , summaries : Dict String ( Reference, WebData DefinitionSummary )
    }


init : Model
init =
    { activeTooltip = Nothing
    , summaries = Dict.empty
    }



-- UPDATE


type Msg
    = ShowTooltip Reference
    | FetchDefinition Reference
    | HideTooltip Reference
    | FetchDefinitionFinished Reference (HttpResult DefinitionSummary)


update : Config -> Msg -> Model -> ( Model, Cmd Msg )
update config msg model =
    let
        debounceDelay =
            300
    in
    case msg of
        ShowTooltip ref ->
            let
                cached =
                    Dict.get (Reference.toString ref) model.summaries
            in
            case cached of
                Nothing ->
                    ( model, Util.delayMsg debounceDelay (FetchDefinition ref) )

                Just _ ->
                    ( { model | activeTooltip = cached }, Cmd.none )

        FetchDefinition ref ->
            case model.activeTooltip of
                Just _ ->
                    ( model, Cmd.none )

                Nothing ->
                    ( { model | activeTooltip = Just ( ref, Loading ) }
                    , fetchDefinition config ref |> HttpApi.perform config.api
                    )

        HideTooltip _ ->
            ( { model | activeTooltip = Nothing }, Cmd.none )

        FetchDefinitionFinished ref d ->
            case model.activeTooltip of
                Just ( r, _ ) ->
                    if Reference.equals ref r then
                        let
                            newActiveTooltip =
                                ( r, RemoteData.fromResult d )

                            updatedAlreadyFetched =
                                Dict.insert (Reference.toString ref) newActiveTooltip model.summaries
                        in
                        ( { model | activeTooltip = Just newActiveTooltip, summaries = updatedAlreadyFetched }, Cmd.none )

                    else
                        ( { model | activeTooltip = Nothing }, Cmd.none )

                Nothing ->
                    ( { model | activeTooltip = Nothing }, Cmd.none )



-- HELPERS


{-| This is intended to be used over `view`, and comes with a way to map the msg.
-}
tooltipConfig : (Msg -> msg) -> Model -> Syntax.TooltipConfig msg
tooltipConfig toMsg model =
    { toHoverStart = ShowTooltip >> toMsg
    , toHoverEnd = HideTooltip >> toMsg
    , toTooltip = \ref -> view model ref
    }



-- EFFECTS


fetchDefinition : Config -> Reference -> ApiRequest DefinitionSummary Msg
fetchDefinition { toApiEndpoint, perspective } ref =
    CodebaseApi.Summary
        { perspective = perspective, ref = ref }
        |> toApiEndpoint
        |> HttpApi.toRequest (decodeSummary ref)
            (FetchDefinitionFinished ref)



-- VIEW


viewSummary : WebData DefinitionSummary -> Maybe (Tooltip.Content msg)
viewSummary summary =
    let
        viewBuiltinType name =
            span
                []
                [ span [ class "data-type-modifier" ] [ text "builtin " ]
                , span [ class "data-type-keyword" ] [ text "type" ]
                , span [ class "type-reference" ] [ text (" " ++ FQN.toString name) ]
                ]

        viewSummary_ s =
            case s of
                TermHover (Term _ _ { signature }) ->
                    Syntax.view Syntax.NotLinked (termSignatureSyntax signature)

                TypeHover (Type _ _ { fqn, source }) ->
                    source
                        |> typeSourceSyntax
                        |> Maybe.map (Syntax.view Syntax.NotLinked)
                        |> Maybe.withDefault (viewBuiltinType fqn)

                AbilityConstructorHover (AbilityConstructor _ { signature }) ->
                    Syntax.view Syntax.NotLinked (termSignatureSyntax signature)

                DataConstructorHover (DataConstructor _ { signature }) ->
                    Syntax.view Syntax.NotLinked (termSignatureSyntax signature)

        loading =
            Tooltip.rich
                (Placeholder.text
                    |> Placeholder.withSize Placeholder.Small
                    |> Placeholder.withLength Placeholder.Small
                    |> Placeholder.withIntensity Placeholder.Subdued
                    |> Placeholder.view
                )
    in
    case summary of
        NotAsked ->
            Just loading

        Loading ->
            Just loading

        Success sum ->
            Just (Tooltip.rich (div [ class "monochrome" ] [ viewSummary_ sum ]))

        Failure _ ->
            Nothing


view : Model -> Reference -> Maybe (Tooltip msg)
view model reference =
    let
        withMatchingReference ( r, d ) =
            if Reference.equals r reference then
                Just d

            else
                Nothing

        view_ d =
            d
                |> viewSummary
                |> Maybe.map Tooltip.tooltip
                |> Maybe.map (Tooltip.withArrow Tooltip.Start)
                |> Maybe.map (Tooltip.withPosition Tooltip.Below)
                |> Maybe.map Tooltip.show
    in
    model.activeTooltip
        |> Maybe.andThen withMatchingReference
        |> Maybe.andThen view_



-- JSON DECODERS


decodeTypeSummary : Decode.Decoder DefinitionSummary
decodeTypeSummary =
    let
        makeSummary fqn name_ source =
            { fqn = fqn
            , name = name_
            , namespace = FQN.namespaceOf name_ fqn
            , source = source
            }
    in
    Decode.map TypeHover
        (Decode.map3 Type
            (field "hash" Hash.decode)
            (Type.decodeTypeCategory [ "tag" ])
            (Decode.map3 makeSummary
                (field "displayName" FQN.decode)
                (field "displayName" FQN.decode)
                (Type.decodeTypeSource [ "summary", "tag" ] [ "summary", "contents" ])
            )
        )


decodeTermSummary : Decode.Decoder DefinitionSummary
decodeTermSummary =
    let
        makeSummary fqn name_ signature =
            { fqn = fqn
            , name = name_
            , namespace = FQN.namespaceOf name_ fqn
            , signature = signature
            }
    in
    Decode.map TermHover
        (Decode.map3 Term
            (field "hash" Hash.decode)
            (Term.decodeTermCategory [ "tag" ])
            (Decode.map3 makeSummary
                (field "displayName" FQN.decode)
                (field "displayName" FQN.decode)
                (Term.decodeSignature [ "summary", "contents" ])
            )
        )


decodeAbilityConstructorSummary : Decode.Decoder DefinitionSummary
decodeAbilityConstructorSummary =
    let
        makeSummary fqn name_ signature =
            { fqn = fqn
            , name = name_
            , namespace = FQN.namespaceOf name_ fqn
            , signature = signature
            }
    in
    Decode.map AbilityConstructorHover
        (Decode.map2 AbilityConstructor
            (field "hash" Hash.decode)
            (Decode.map3 makeSummary
                (field "displayName" FQN.decode)
                (field "displayName" FQN.decode)
                (DataConstructor.decodeSignature [ "summary", "contents" ])
            )
        )


decodeDataConstructorSummary : Decode.Decoder DefinitionSummary
decodeDataConstructorSummary =
    let
        makeSummary fqn name_ signature =
            { fqn = fqn
            , name = name_
            , namespace = FQN.namespaceOf name_ fqn
            , signature = signature
            }
    in
    Decode.map DataConstructorHover
        (Decode.map2 DataConstructor
            (at [ "hash" ] Hash.decode)
            (Decode.map3 makeSummary
                (field "displayName" FQN.decode)
                (field "displayName" FQN.decode)
                (DataConstructor.decodeSignature [ "summary", "contents" ])
            )
        )


decodeSummary : Reference -> Decode.Decoder DefinitionSummary
decodeSummary ref =
    case ref of
        TermReference _ ->
            decodeTermSummary

        TypeReference _ ->
            decodeTypeSummary

        AbilityConstructorReference _ ->
            decodeAbilityConstructorSummary

        DataConstructorReference _ ->
            decodeDataConstructorSummary
