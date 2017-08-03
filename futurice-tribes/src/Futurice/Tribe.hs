{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}
module Futurice.Tribe (
    Tribe,
    mkTribe,
    tribeToText,
    tribeFromText,
    _Tribe,
    tribeOffices,
    ) where

import Futurice.Generics
import Futurice.Office
import Futurice.Prelude
import Futurice.Tribe.Internal
import Language.Haskell.TH     (ExpQ)
import Lucid                   (ToHtml (..))
import Prelude ()

import qualified Data.Aeson.Compat as Aeson
import qualified Data.Map          as Map
import qualified Data.Swagger      as Swagger
import qualified Data.Text         as T
import qualified Data.Vector       as V
import qualified Test.QuickCheck   as QC

-- | Tribe.
newtype Tribe = Tribe Int
  deriving (Eq, Ord)

deriveLift ''Tribe

instance Show Tribe where
    showsPrec d t = showsPrec d (tribeToText t)

-------------------------------------------------------------------------------
-- Magic
-------------------------------------------------------------------------------

-- | Vector to have constant time lookups.
tribeInfos :: Vector TribeInfo
tribeInfos
    = V.fromList
    $ sortOn tiName
    $ $(makeRelativeToProject "tribes.json" >>= embedFromJSON (Proxy :: Proxy [TribeInfo]))

-- | Map from lowercased tribe names and aliases to index in tribeInfos and TribeInfo itself
tribeLookup :: Map Text (Int, TribeInfo)
tribeLookup
    = Map.fromList
    $ concatMap f
    $ zip [0..]
    $ toList tribeInfos
  where
    f (i, ti) = [ (T.toLower k, (i, ti)) | k <- tiName ti : tiAliases ti ]

-------------------------------------------------------------------------------
-- Template Haskell
-------------------------------------------------------------------------------

-- | create tribe compile time.
--
-- /Note:/ use only in tests, do not hardcode tribes!
mkTribe :: String -> ExpQ
mkTribe n
    | Just t <- tribeFromText (n ^. packed) = [| t |]
    | otherwise = fail $ "Invalid tribe name: " ++ n

-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------

tribeInfo :: Tribe -> TribeInfo
tribeInfo (Tribe i)
    = fromMaybe (error "tribeInfo: invalid Tribe")
    $ tribeInfos ^? ix i

tribeName :: Tribe -> Text
tribeName = tiName . tribeInfo

tribeOffices :: Tribe -> [Office]
tribeOffices = tiOffices . tribeInfo

-------------------------------------------------------------------------------
-- Instances
-------------------------------------------------------------------------------

tribeToText :: Tribe -> Text
tribeToText = tribeName

tribeFromText :: Text -> Maybe Tribe
tribeFromText k = Tribe <$> tribeLookup ^? ix (T.toLower k) . _1

tribeFromTextE :: Text -> Either String Tribe
tribeFromTextE k =
    maybe (Left $ "Invalid tribe " ++ show k) Right (tribeFromText k)

_Tribe :: Prism' Text Tribe
_Tribe = prism' tribeToText tribeFromText

instance NFData Tribe where
    rnf (Tribe i) = rnf i

instance Arbitrary Tribe where
    arbitrary = QC.elements [ Tribe i | i <- [0 .. V.length tribeInfos - 1] ]

instance ToHtml Tribe where
    toHtmlRaw = toHtml
    toHtml = toHtml . tribeToText

instance ToParamSchema Tribe where
    toParamSchema _ = mempty
        & Swagger.type_ .~ Swagger.SwaggerString
        -- & Swagger.enum_ ?~ map enumToJSON_ enumUniverse_

instance ToSchema Tribe where
    declareNamedSchema p = pure $ Swagger.NamedSchema (Just "Tribe") $ mempty
        & Swagger.paramSchema .~ toParamSchema p

instance ToJSON Tribe where
    toJSON = Aeson.String . tribeToText

instance FromJSON Tribe where
    parseJSON = Aeson.withText "Tribe" $
        either (fail . view unpacked) pure . tribeFromTextE

instance FromHttpApiData Tribe where
    parseUrlPiece = first (view packed) . tribeFromTextE

instance ToHttpApiData Tribe where
    toUrlPiece = tribeToText