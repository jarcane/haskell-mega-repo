{-# LANGUAGE CPP                     #-}
{-# LANGUAGE DataKinds               #-}
{-# LANGUAGE FlexibleContexts        #-}
{-# LANGUAGE GADTs                   #-}
{-# LANGUAGE OverloadedStrings       #-}
{-# LANGUAGE ScopedTypeVariables     #-}
{-# LANGUAGE TypeFamilies            #-}
{-# LANGUAGE UndecidableInstances    #-}
#if __GLASGOW_HASKELL__ >= 800
{-# LANGUAGE UndecidableSuperClasses #-}
#endif

-- | Simple but awesome form library.
--
-- /TODO:/ mode to @futurice-prelude@ after stabilised.
module Futurice.Lomake (
    module Futurice.Lomake,
    -- * Re-exports
    SOP.IsProductType,
    ) where

import Control.Monad.Fail         (MonadFail)
import Control.Monad.State.Strict
import Data.Maybe                 (isNothing)
import Data.Swagger               (NamedSchema (..))
import Futurice.Generics
import Futurice.List              (UnSingleton)
import Futurice.Lucid.Foundation
import Futurice.Prelude
import Prelude ()
import Servant.API                (Link)

-- import Generics.SOP              hiding (FieldName)

import qualified Data.Aeson.Compat   as Aeson
import qualified Data.HashMap.Strict as HM
import qualified Generics.SOP        as SOP

-------------------------------------------------------------------------------
-- FieldName
-------------------------------------------------------------------------------

type FieldName = Text

class HasFieldName a where
    fieldName :: Lens' a FieldName

-------------------------------------------------------------------------------
-- Field
-------------------------------------------------------------------------------

data Field a where
    TextField   :: TextFieldOptions a -> Field a
    HiddenField :: TextFieldOptions a -> Field a
    EnumField   :: EnumFieldOptions a -> Field a

-------------------------------------------------------------------------------
-- TextField
-------------------------------------------------------------------------------

data TextFieldOptions a = TextFieldOptions
    { tfoName   :: FieldName
    , tfoEncode :: a -> Text
    , tfoDecode :: Text -> Either Text a
    }

instance HasFieldName (TextFieldOptions a) where
    fieldName = lens tfoName $ \s x -> s { tfoName = x }

-------------------------------------------------------------------------------
-- EnumField
-------------------------------------------------------------------------------

data EnumFieldOptions a = EnumFieldOptions
    { efoName   :: FieldName
    , efoEncode :: a -> Text
    , efoDecode :: Text -> Either Text a
    , efoValues :: [(a, Text)]
    }

instance HasFieldName (EnumFieldOptions a) where
    fieldName = lens efoName $ \s x -> s { efoName = x }

-------------------------------------------------------------------------------
-- Field smart constructors
-------------------------------------------------------------------------------

textField
    :: (ToHttpApiData a, FromHttpApiData a)
    => FieldName -> Field a
textField n = TextField TextFieldOptions
    { tfoName   = n
    , tfoEncode = toQueryParam
    , tfoDecode = parseQueryParam
    }

hiddenField
    :: (ToHttpApiData a, FromHttpApiData a)
    => FieldName -> Field a
hiddenField n = HiddenField TextFieldOptions
    { tfoName   = n
    , tfoEncode = toQueryParam
    , tfoDecode = parseQueryParam
    }

enumField
    :: (Enum a, Bounded a, ToHttpApiData a, FromHttpApiData a, ToHtml a)
    => FieldName -> (a -> Text) -> Field a
enumField n label = EnumField EnumFieldOptions
    { efoName   = n
    , efoEncode = toQueryParam
    , efoDecode = parseQueryParam
    , efoValues = [ (x, label x) | x <- [minBound .. maxBound] ]
    }

dynEnumField
    :: (ToHttpApiData a, FromHttpApiData a, ToHtml a)
    => FieldName -> Field a
dynEnumField n = EnumField EnumFieldOptions
    { efoName   = n
    , efoEncode = toQueryParam
    , efoDecode = parseQueryParam
    , efoValues = []
    }

-------------------------------------------------------------------------------
-- Markup
-------------------------------------------------------------------------------

-- | Form rendering options.
data FormOptions = FormOptions
    { foName :: !Text  -- ^ name of the form
    , foUrl  :: !Link  -- ^ url where to submit the form
    }
  deriving (Show)

-- | The default values for form elements.
--
-- See smart constructors: 'vJust', 'vNothing', 'vHidden', 'vDynamic'.
data V a
    = V (Maybe a) [(a, Text)]  -- ^ basic value, the list value is used to populate enum fields.
    | VHidden a                -- ^ value set, renders field hidden.

vJust :: a -> V a
vJust x = V (Just x) []

vNothing :: V a
vNothing = V Nothing []

vHidden :: a -> V a
vHidden = VHidden

vDynamic :: [(a, Text)] -> V a
vDynamic = V Nothing

-- | 'maybe' for 'V'.
vMaybe :: b -> (a -> b) -> V a -> b
vMaybe  def f (V x _)     = maybe def f x
vMaybe _def f (VHidden x) = f x

-- | Render lomake HTML form.
lomakeHtml
    :: forall xs m. Monad m
    => FormOptions      -- ^ form options
    -> NP Field xs      -- ^ field descriptions
    -> NP (K Text) xs   -- ^ field names
    -> NP V xs          -- ^ values
    -> HtmlT m ()
lomakeHtml formOpts fields names values =
    row_ formAttributes $ large_ 12 $ do
        -- inputs
        evalStateT (go fields names values) mempty

        -- buttons
        row_ $ large_ 12 $ div_ [ class_ "button-group" ] $ do
            button_ [ class_ "button success", data_ "lomake-action" "submit", disabled_ "disabled" ] "Submit"
            button_ [ class_ "button", data_ "lomake-action" "reset", disabled_ "disabled" ] "Reset"
  where
    formAttributes =
        [ data_ "lomake-form" $ foName formOpts
        , data_ "lomake-form-submit" $ toUrlPiece $ foUrl formOpts
        ]

    go :: NP Field ys -> NP (K Text) ys -> NP V ys -> StateT () (HtmlT m) ()
    go (f :* fs) (K n :* ns) (x :* xs) = render f n x >> go fs ns xs
    go Nil Nil Nil                     = pure ()

    render :: forall a. Field a -> Text -> V a -> StateT () (HtmlT m) ()
    render (HiddenField opts) n value = do
        lift $ input_
            [ data_ "lomake-id" n
            , name_ n
            , type_ "hidden"
            , value_ $ vMaybe "" (tfoEncode opts) value
            ]

    render (TextField opts) n v@VHidden {} = 
        render (HiddenField opts) n v
    render (TextField opts) n value = do
        lift $ row_ $ large_ 12 $ label_ $ do
            toHtml (opts ^. fieldName) -- TODO: use label?
            input_
                [ data_ "lomake-id" n
                , name_ n
                , type_ "text"
                , value_ $ vMaybe "" (tfoEncode opts) value
                ]

    render (EnumField opts) n v@VHidden {} =
        render (HiddenField opts') n v
      where
        -- TODO: make 'Lens opts HiddenFieldOpts'
        opts' = TextFieldOptions
            { tfoName = efoName opts
            , tfoEncode = efoEncode opts
            , tfoDecode = efoDecode opts
            }

    render (EnumField opts) n value = do
        let p = efoEncode opts
        let mValue = vMaybe Nothing Just value
        lift $ row_ $ large_ 12 $ label_ $ do
            toHtml (opts ^. fieldName) -- TODO: use label?
            select_ [ data_ "lomake-id" n, name_ n ] $ do
                when (isNothing mValue) $
                    optionSelected_ True [] "-"

                for_ vals $ \(v, l) ->
                    optionSelected_ (fmap p mValue == Just (p v))
                        [ value_ $ p v ]
                        (toHtml l)
      where
        vals = case value of 
            V _ xs | not (null xs) -> xs
            _                      -> efoValues opts

-------------------------------------------------------------------------------
-- FromJSON
-------------------------------------------------------------------------------

lomakeParseJSON
    :: SOP.IsProductType a xs
    => NP Field xs     -- ^ field descriptions
    -> NP (K Text) xs  -- ^ field names
    -> Value
    -> Aeson.Parser a
lomakeParseJSON fs ns value = do
    values <- parseJSON value
    lomakeParseJSON' values fs ns

lomakeParseJSON'
    :: forall a xs m. (SOP.IsProductType a xs, MonadFail m)
    => HashMap Text Text
    -> NP Field xs     -- ^ field descriptions
    -> NP (K Text) xs  -- ^ field names
    -> m a
lomakeParseJSON' hm fs ns =
    fmap (SOP.to . SOP.SOP . SOP.Z) $ SOP.hsequence $ SOP.hzipWith parse fs ns
  where
    parse :: Field x -> K Text x -> m x
    parse (HiddenField opts) (K n) = do
        lookupField n (tfoDecode opts)
    parse (TextField opts) (K n) = do
        lookupField n (tfoDecode opts)
    parse (EnumField opts) (K n)= do
        lookupField n (efoDecode opts)

    lookupField :: FieldName -> (Text -> Either Text x) -> m x
    lookupField n decoder = case HM.lookup n hm of
        Nothing -> fail $ "Missing field " ++ n ^. unpacked
        Just t  -> either (fail . errorFormat n) pure (decoder t)

    errorFormat :: FieldName -> Text -> String
    errorFormat n err = "field " ++ n ^. unpacked ++ ": " ++ err ^. unpacked

-------------------------------------------------------------------------------
-- Lomake Request
-------------------------------------------------------------------------------

class (SOP.IsProductType a (LomakeCode a), SOP.HasDatatypeInfo a) => HasLomake a where
    type LomakeCode a :: [*]
    type LomakeCode a = UnSingleton (SOP.Code a)

    lomake :: Proxy a -> NP Field (LomakeCode a)

-- | A newtype to allow parsing different 'Lomake'
newtype LomakeRequest a = LomakeRequest { getLomakeRequest :: a }

instance HasLomake a => FromJSON (LomakeRequest a) where
    parseJSON = fmap LomakeRequest . lomakeParseJSON (lomake p) (strippedFieldNames p)
      where
        p = Proxy :: Proxy a

-- | TODO: HasLomake should require something?
instance ToSchema (LomakeRequest a) where
    declareNamedSchema _ = pure $ NamedSchema (Just "Lomake") mempty

-------------------------------------------------------------------------------
-- Lomake Response
-------------------------------------------------------------------------------

data LomakeResponse
    = LomakeResponseNoop            -- ^ Do nothing
    | LomakeResponseError String    -- ^ an error
    | LomakeResponseReload          -- ^ reload current page
    | LomakeResponseRedirect !Text  -- ^ redirect to the url
  deriving (Eq, Ord, Show, Typeable, Generic)

instance ToJSON LomakeResponse
instance FromJSON LomakeResponse
instance ToSchema LomakeResponse
