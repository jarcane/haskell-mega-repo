{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
module Futurice.App.MegaRepoTool.Command.BuildDocker (
    buildDocker,
    Image,
    ) where

import Futurice.Prelude hiding (fold)
import Turtle           hiding (when, (<>))

import Control.Lens (ifor_)
import System.Exit  (exitFailure)
import System.IO    (hClose, hFlush)

import qualified Control.Foldl as Fold
import qualified Data.Map      as Map
import qualified Data.Text     as T
import qualified Data.Text.IO  as T

type Image = Text
type Executable = Text

apps :: Map Image Executable
apps = Map.fromList
    [ ("avatar", "avatar-server")
    , ("contacts-api", "contacts-server")
    , ("favicon", "favicon")
    , ("futuhours-api", "futuhours-api-server")
    , ("proxy-app", "proxy-app-server")
    , ("reports-app", "reports-app-server")
    , ("spice-stats", "spice-stats-server")
    , ("theme-app", "theme-app-server")
    ]

buildImage :: Text
buildImage = "futurice/base-images:haskell-lts-6.3-1"

buildCmd :: Text
buildCmd = T.unwords
    [ "docker run"
    , "--rm"
    , "-ti"
    , "--entrypoint /app/src/build-in-docker.sh"
    , "-v $(pwd):/app/src"
    , "-v $(pwd)/build:/app/bin"
    , buildImage
    ]

buildDocker :: [Image] -> IO ()
buildDocker imgs = do
    let apps' | null imgs = apps
              | otherwise = Map.filterWithKey (\k _ -> k `elem` imgs) apps
    -- Get the hash of current commit
    githash <- fold (inshell "git log --pretty=format:'%h' -n 1" empty) $ Fold.lastDef "HEAD"
    shells ("git rev-parse --verify " <> githash) empty
    T.putStrLn $ "Git hash aka tag for images: " <> githash

    -- Check that binaries are build with current hash
    githashBuild <- (T.strip <$> T.readFile "build/git-hash.txt") `catch` onIOError "<none>"
    when (githashBuild /= githash) $ do
        T.putStrLn $ "Git hash in build directory don't match: " <> githashBuild  <> " != " <> githash
        T.putStrLn $ "Run following command to build image:"
        T.putStrLn $ buildCmd
        exitFailure

    -- Build docker images
    ifor_ apps' $ \image exe -> sh $ do
        -- Write Dockerfile
        let dockerfile' = dockerfile exe
        (file,handle) <- using $ mktemp "build" "Dockerfile"
        liftIO $ do
            T.hPutStrLn handle dockerfile'
            hFlush handle
            hClose handle

        -- Build an image
        let fullimage = "futurice/" <> image <> ":" <> githash
        procs "docker" ["build", "-t", fullimage, "-f", format fp file, "build" ] empty

dockerfile :: Executable -> Text
dockerfile exe = T.unlines $
    [ "FROM ubuntu:trusty"
    , "MAINTAINER Oleg Grenrus <oleg.grenrus@iki.fi>"
    , "RUN apt-get -yq update && apt-get -yq --no-install-suggests --no-install-recommends --force-yes install " <> T.intercalate " " debs <> " && rm -rf /var/lib/apt/lists/*"
    , "RUN useradd -m -s /bin/bash -d /app app"
    , "WORKDIR /app"
    , "ADD " <> exe <> " /app"
    , "RUN chown -R app:app /app"
    , "EXPOSE 8000"
    , "USER app"
    , "WORKDIR /app"
    , "CMD [\"/app/" <> exe <> "\", \"+RTS\", \"-N\", \"-T\"]"
    ]
  where
    debs =
        [ "ca-certificates"
        , "libfftw3-bin"
        , "libgmp10"
        , "libpq5"
        ]

onIOError :: Monad m => a -> IOError -> m a
onIOError v _ = return v
