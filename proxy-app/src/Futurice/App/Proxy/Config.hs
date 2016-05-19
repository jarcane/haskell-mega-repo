{-# LANGUAGE GADTs #-}
module Futurice.App.Proxy.Config (
    Config(..),
    getConfig,
    defaultPort,
    ) where

import Futurice.Prelude
import Prelude          ()

import Data.ByteString    (ByteString)
import System.Environment (lookupEnv)

import qualified Data.Text                 as T

data Config = Config
    { cfgPort             :: !Int
    , cfgFutuhoursBaseurl :: !String
    }

-- | TODO: parse
getConfig :: IO Config
getConfig = Config
    <$> parseEnvVarWithDefault "PORT" defaultPort
    <*> parseEnvVar "FUTUHOURS_BASEURL"

defaultPort :: Int
defaultPort = 8000

-- | Class to parse env variables
class FromEnvVar a where
    fromEnvVar :: String -> Maybe a

-- | Parse required environment variable
parseEnvVar :: FromEnvVar a
            => String  -- ^ Environment variable
            -> IO a
parseEnvVar var =
    parseEnvVarWithDefault var (error $ "No environment variable " ++ var)

-- | Parse optional environment variable.
-- Will fail if variable is present, but is of invalid format.
parseEnvVarWithDefault :: FromEnvVar a
                       => String  -- ^ Environment variable
                       -> a       -- ^ Default value
                       -> IO a
parseEnvVarWithDefault var def = do
    val <- lookupEnv var
    case val of
        Nothing   -> pure def
        Just val' -> case fromEnvVar val' of
            Nothing -> error $
               "Cannot parse environment variable: " ++ var ++ " -- " ++ val'
            Just x  -> pure x

-- | This instance is temporary.
instance a ~ Char => FromEnvVar [a] where
    fromEnvVar = Just

instance FromEnvVar ByteString where
    fromEnvVar = Just . fromString

instance FromEnvVar T.Text where
    fromEnvVar = Just . T.pack

instance FromEnvVar Word64 where
    fromEnvVar = readMaybe

instance FromEnvVar Int where
    fromEnvVar = readMaybe