{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE TemplateHaskell   #-}
module Futurice.App.Theme (defaultMain) where

import Futurice.Prelude
import Prelude ()

import Futurice.EnvConfig             (getConfig)
import Futurice.Servant
import Network.Wai.Application.Static (embeddedSettings, staticApp)
import Servant
import Servant.Swagger.UI.Internal    (mkRecursiveEmbedded)
import System.IO                      (hPutStrLn, stderr)

import qualified Network.Wai.Handler.Warp as Warp

import Futurice.App.Theme.Config
import Futurice.App.Theme.Server.API
import Futurice.App.Theme.Types

-- | API server
server :: Server ThemeAPI
server = pure IndexPage :<|> static
  where
    -- | TODO: move to own file
    static = staticApp $ embeddedSettings $(mkRecursiveEmbedded "images")

server' :: DynMapCache -> Server ThemeAPI'
server' cache = futuriceServer
    "Theme APP"
    "there aren't really an API"
    cache themeApi server

-- | Wai application
app :: DynMapCache -> Application
app = serve themeApi' . server'

defaultMain :: IO ()
defaultMain = do
    hPutStrLn stderr "Hello, theme-app is alive"
    Config {..} <- getConfig
    cache <- newDynMapCache
    hPutStrLn stderr $ "Starting web server in port " ++ show cfgPort
    Warp.run cfgPort $ app cache
