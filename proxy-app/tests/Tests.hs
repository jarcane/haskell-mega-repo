{-# LANGUAGE GADTs             #-}
{-# LANGUAGE OverloadedStrings #-}
module Main (main) where

import Data.Binary.Tagged
import Futurice.Prelude
import GHC.TypeLits          (natVal)
import Prelude ()
import Test.Tasty
import Test.Tasty.QuickCheck

import qualified Data.ByteString.Base16.Lazy as Base16
import qualified Futurice.GitHub             as GH
import qualified PlanMill.Types              as PM
import qualified PlanMill.Types.Query        as PM

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "proxy-app"
    [ binaryTagTests
    ]

data BTTest where
    BTTest
        :: (HasStructuralInfo a, HasSemanticVersion a)
        => String -> Proxy a -> Int -> LazyByteString -> BTTest

binaryTagTests :: TestTree
binaryTagTests = testGroup "BinaryTagged tags" $ map mk tags
  where
    mk :: BTTest -> TestTree
    mk (BTTest name p ver h) = testProperty name $ once $
        ver === fromIntegral (natVal (versionProxy p)) .&&.
        h === Base16.encode (structuralInfoSha1ByteStringDigest (structuralInfo p))

    versionProxy :: Proxy a -> Proxy (SemanticVersion a)
    versionProxy _ = Proxy

    tags :: [BTTest]
    tags =
        [ BTTest "PlanMill.SomeResponse" (Proxy :: Proxy PM.SomeResponse)
            0 "4310fad12af8a9cecb57eb4828c0cb0e22835d0c"
        , BTTest "planmill-haxl endpoint" (Proxy :: Proxy [Either Text PM.SomeResponse])
            0 "c39df9348a4b9762281366f2382e355ba991dc8f"
        , BTTest "PlanMill.Projects" (Proxy :: Proxy PM.Projects)
            0 "df7ab11865b56c8350dfc6afde343224509ddf2c"
        , BTTest "PlanMill.Tasks" (Proxy :: Proxy PM.Tasks)
            0 "c0af841c9b60ca6217cd9cfb05eaa568ef3b89b1"
        , BTTest "PlanMill.CapacityCalendars" (Proxy :: Proxy PM.CapacityCalendars)
            0 "1fde910b8a5fc395de41cf0cda34f17fe9d141cd"
        , BTTest "GitHub.SomeResponse" (Proxy :: Proxy GH.SomeResponse)
            0 "8a6e66865d0dd5f2da6d4d63389b4b24d01b1ae3"
        ]
