module Component.BMark where

import Prelude hiding (div)

import App (StarAction(..), destroy, editBookmark, markRead, toggleStar)
import Data.Array (drop, foldMap)
import Data.Lens (Lens', lens, use, (%=), (.=))
import Data.Maybe (Maybe(..), fromMaybe, isJust, maybe)
import Data.Monoid (guard)
import Data.Nullable (toMaybe)
import Data.String (null, split, take) as S
import Data.String.Pattern (Pattern(..))
import Data.Tuple (fst, snd)
import Effect.Aff (Aff)
import Globals (app', mmoment8601)
import Halogen as H
import Halogen.HTML (HTML, a, br_, button, div, div_, form, input, label, span, text, textarea)
import Halogen.HTML.Events (onSubmit, onValueChange, onChecked, onClick)
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties (ButtonType(..), InputType(..), autocomplete, checked, for, href, id_, name, required, rows, target, title, type_, value)
import Model (Bookmark)
import Util (class_, attr, fromNullableStr)
import Web.Event.Event (Event, preventDefault)

-- | UI Events
data BQuery a
  = BStar Boolean a
  | BDeleteAsk Boolean a
  | BDestroy a
  | BEdit Boolean a
  | BEditField EditField a
  | BEditSubmit Event a
  | BMarkRead a

-- | FormField Edits
data EditField
  = Eurl String
  | Etitle String
  | Edescription String
  | Etags String
  | Eprivate Boolean
  | Etoread Boolean

-- | Messages to parent
data BMessage
  = BNotifyRemove

type BState =
  { bm :: Bookmark
  , edit_bm :: Bookmark
  , deleteAsk:: Boolean
  , edit :: Boolean
  }

_bm :: Lens' BState Bookmark
_bm = lens _.bm (_ { bm = _ })

_edit_bm :: Lens' BState Bookmark
_edit_bm = lens _.edit_bm (_ { edit_bm = _ })

_edit :: Lens' BState Boolean
_edit = lens _.edit (_ { edit = _ })

bmark :: Bookmark -> H.Component HTML BQuery Unit BMessage Aff
bmark b' =
  H.component
    { initialState: const (mkState b')
    , render
    , eval
    , receiver: const Nothing
    }
  where
  app = app' unit

  mkState b =
    { bm: b
    , edit_bm: b
    , deleteAsk: false
    , edit: false
    }

  render :: BState -> H.ComponentHTML BQuery
  render s@{ bm, edit_bm } =
    div [ id_ (show bm.bid) , class_ ("bookmark w-100 mw7 pa1 mb3" <> guard bm.private " private")] $
      star <>
      if s.edit
        then display_edit
        else display
    where

     star =
       guard app.dat.isowner
         [ div [ class_ ("star fl pointer" <> guard bm.selected " selected") ]
           [ button [ class_ "moon-gray", onClick (HE.input_ (BStar (not bm.selected))) ] [ text "✭" ] ]
         ]

     display =
       [ div [ class_ "display" ] $
         [ a [ href bm.url, target "_blank", class_ ("link f5 lh-title" <> guard bm.toread " unread")]
           [ text $ if S.null bm.title then "[no title]" else bm.title ]
         , br_
         , a [ href bm.url , class_ "link f7 gray hover-blue" ] [ text bm.url ]
         , a [ href (fromMaybe ("http://archive.is/" <> bm.url) (toMaybe bm.archiveUrl))
             , class_ ("link f7 gray hover-blue ml2" <> (guard (isJust (toMaybe bm.archiveUrl)) " green"))
             , target "_blank", title "archive link"]
             [ if isJust (toMaybe bm.archiveUrl) then text "☑" else text "☐" ]
         , br_
           -- 
         , div [ class_ "description mt1 mid-gray" ] (toTextarea bm.description)
         , div [ class_ "tags" ] $
             guard (not (S.null bm.tags))
               map (\tag -> a [ class_ ("link tag mr1" <> guard (S.take 1 tag == ".") " private")
                            , href (linkToFilterTag tag) ]
                            [ text tag ])
               (S.split (Pattern " ") bm.tags)
         , a [ class_ "link f7 dib gray w4", title (maybe bm.time snd mmoment) , href (linkToFilterSingle bm.slug) ]
           [ text (maybe " " fst mmoment) ]
         ]
         <> links
       ]

     display_edit =
       [ div [ class_ "edit_bookmark_form pa2 pt0 bg-white" ] $
         [ form [ onSubmit (HE.input BEditSubmit) ]
           [ div_ [ text "url" ]
           , input [ type_ InputUrl , class_ "url w-100 mb2 pt1 f7 edit_form_input" , required true , name "url"
                   , value (edit_bm.url) , onValueChange (editField Eurl) ]
           , br_
           , div_ [ text "title" ]
           , input [ type_ InputText , class_ "title w-100 mb2 pt1 f7 edit_form_input" , name "title"
                   , value (edit_bm.title) , onValueChange (editField Etitle) ]
           , br_
           , div_ [ text "description" ]
           , textarea [ class_ "description w-100 mb1 pt1 f7 edit_form_input" , name "description", rows 5
                      , value (edit_bm.description) , onValueChange (editField Edescription) ]
           , br_
           , div [ id_ "tags_input_box"]
             [ div_ [ text "tags" ]
               , input [ type_ InputText , class_ "tags w-100 mb1 pt1 f7 edit_form_input" , name "tags"
                       , autocomplete false, attr "autocapitalize" "off"
                       , value (edit_bm.tags) , onValueChange (editField Etags) ]
               , br_
             ]
           , div [ class_ "edit_form_checkboxes mv3"]
             [ input [ type_ InputCheckbox , class_ "private pointer" , id_ "edit_private", name "private"
                     , checked (edit_bm.private) , onChecked (editField Eprivate) ]
             , text " "
             , label [ for "edit_private" , class_ "mr2" ] [ text "private" ]
             , text " "
             , input [ type_ InputCheckbox , class_ "toread pointer" , id_ "edit_toread", name "toread"
                     , checked (edit_bm.toread) , onChecked (editField Etoread) ]
             , text " "
             , label [ for "edit_toread" ] [ text "to-read" ]
             , br_
             ]
           , input [ type_ InputSubmit , class_ "mr1 pv1 ph2 dark-gray ba b--moon-gray bg-near-white pointer rdim" , value "save" ]
           , text " "
           , input [ type_ InputReset , class_ "pv1 ph2 dark-gray ba b--moon-gray bg-near-white pointer rdim" , value "cancel"
                   , onClick (HE.input_ (BEdit false)) ]
           ]
         ]
       ]

     links =
       guard app.dat.isowner
         [ div [ class_ "edit_links di" ]
           [ button [ type_ ButtonButton, onClick (HE.input_ (BEdit true)), class_ "edit light-silver hover-blue" ] [ text "edit  " ]
           , div [ class_ "delete_link di" ]
             [ button [ type_ ButtonButton, onClick (HE.input_ (BDeleteAsk true)), class_ ("delete light-silver hover-blue" <> guard s.deleteAsk " dn") ] [ text "delete" ]
             , span ([ class_ ("confirm red" <> guard (not s.deleteAsk) " dn") ] )
               [ button [ type_ ButtonButton, onClick (HE.input_ (BDeleteAsk false))] [ text "cancel / " ]
               , button [ type_ ButtonButton, onClick (HE.input_ BDestroy), class_ "red" ] [ text "destroy" ]
               ] 
             ]
           ]
         , div [ class_ "read di" ] $
             guard bm.toread
             [ text "  "
             , button [ onClick (HE.input_ BMarkRead), class_ "mark_read" ] [ text "mark as read"]
             ]
         ]

     editField :: forall a. (a -> EditField) -> a -> Maybe (BQuery Unit)
     editField f = HE.input BEditField <<< f
     linkToFilterSingle slug = fromNullableStr app.userR <> "/b:" <> slug
     linkToFilterTag tag = fromNullableStr app.userR <> "/t:" <> tag
     mmoment = mmoment8601 bm.time
     toTextarea input =
       S.split (Pattern "\n") input
       # foldMap (\x -> [br_, text x])
       # drop 1

  eval :: BQuery ~> H.ComponentDSL BState BQuery BMessage Aff

  -- | Star
  eval (BStar e next) = do
    bm <- use _bm
    H.liftAff (toggleStar bm.bid (if e then Star else UnStar))
    _bm %= _ { selected = e }
    _edit_bm %= _ { selected = e }
    pure next

  -- | Delete
  eval (BDeleteAsk e next) = do
    H.modify_ (_ { deleteAsk = e })
    pure next

  -- | Destroy
  eval (BDestroy next) = do
    bm <- use _bm
    void $ H.liftAff (destroy bm.bid)
    H.raise BNotifyRemove
    pure next

  -- | Mark Read
  eval (BMarkRead next) = do
    bm <- use _bm
    void (H.liftAff (markRead bm.bid))
    _bm %= _ { toread = false }
    pure next

  -- | Start/Stop Editing
  eval (BEdit e next) = do
    bm <- use _bm
    _edit_bm .= bm
    _edit .= e
    pure next

  -- | Update Form Field 
  eval (BEditField f next) = do
    _edit_bm %= case f of
      Eurl e -> _ { url = e }
      Etitle e -> _ { title = e }
      Edescription e -> _ { description = e }
      Etags e -> _ { tags = e }
      Eprivate e -> _ { private = e }
      Etoread e -> _ { toread = e }
    pure next

  -- | Submit
  eval (BEditSubmit e next) = do
    H.liftEffect (preventDefault e)
    edit_bm <- use _edit_bm
    void $ H.liftAff (editBookmark edit_bm)
    _bm .= edit_bm
    _edit .= false
    pure next