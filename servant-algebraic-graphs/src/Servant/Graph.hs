{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE DeriveDataTypeable    #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE KindSignatures        #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
module Servant.Graph (
    ALGA,
    ALGAPNG,
    Graph (..),
    ToDot (..),
    ToDotVertex (..)
    ) where

import Control.DeepSeq                (NFData (..))
import Data.Proxy                     (Proxy (..))
import Data.String                    (fromString)
import Data.Swagger                   (NamedSchema (..), ToSchema (..))
import Data.Typeable                  (Typeable)
import GHC.TypeLits                   (KnownSymbol, Symbol, symbolVal)
import Servant.API                    (Accept (..), MimeRender (..))
import System.Process.ByteString.Lazy (readProcessWithExitCode)

import qualified Algebra.Graph           as G
import qualified Algebra.Graph.Class     as ALGA
import qualified Algebra.Graph.ToGraph     as ALGA
import qualified Data.ByteString.Lazy    as LBS
import qualified Data.Text          as T
import qualified Data.Text.Lazy          as LT
import qualified Data.Text.Lazy.Encoding as LTE
import qualified Network.HTTP.Media      as M
import qualified Algebra.Graph.Export.Dot as Dot

import System.IO.Unsafe (unsafePerformIO)

-------------------------------------------------------------------------------
-- Servant
-------------------------------------------------------------------------------

data ALGA deriving Typeable
data ALGAPNG deriving Typeable

-- | @image/svg+xml@
instance Accept ALGA where
    contentType _ = "application" M.// "pdf"

instance ToDot g => MimeRender ALGA g where
    mimeRender _ = renderDot "pdf"

-- | @image/svg+xml@
instance Accept ALGAPNG where
    contentType _ = "image" M.// "png"

instance ToDot g => MimeRender ALGAPNG g where
    mimeRender _ = renderDot "png"

-- | Dot style
class (ALGA.ToGraph g, Ord (ALGA.ToVertex g)) => ToDot g where
    exportStyle :: proxy g -> Dot.Style (ALGA.ToVertex g) LT.Text

class Ord a => ToDotVertex a where
    exportVertexStyle :: Dot.Style a LT.Text

instance ToDotVertex a => ToDot (G.Graph a) where
    exportStyle _ = exportVertexStyle


instance ToDotVertex T.Text where
    exportVertexStyle = (Dot.defaultStyle $ LT.fromStrict . T.concatMap escape)
        { Dot.vertexAttributes = va
        , Dot.graphAttributes =
            [ "rankdir" Dot.:= "LR"
            ]
        }
      where
        va _ =
            [  "shape" Dot.:= "box"
            ]

        escape '"'  = "\\\""
        escape '\\' = "\\\\"
        escape c    = T.singleton c

-------------------------------------------------------------------------------
-- Internals
-------------------------------------------------------------------------------

renderDot :: forall g. ToDot g => String -> g -> LBS.ByteString
renderDot typ g
    = (\(_, x, _) -> x)
    $ unsafePerformIO
    $ readProcessWithExitCode "dot" ["-T" ++ typ] -- make configurable!
    $ LTE.encodeUtf8
    $ Dot.export style g
  where
    style = style'
        { Dot.graphAttributes = ("overlap" Dot.:= "false") : Dot.graphAttributes style'
        }
    style' = exportStyle (Proxy :: Proxy g)

-------------------------------------------------------------------------------
-- Graph
-------------------------------------------------------------------------------

newtype Graph a (name :: Symbol) = Graph (G.Graph a)

-- https://github.com/snowleopard/alga/issues/25
instance NFData a => NFData (Graph a name) where
    rnf (Graph _) = rnf ()

instance ALGA.Graph (Graph a name) where
    type Vertex (Graph a name) = a

    empty = Graph G.empty
    vertex = Graph . G.vertex
    Graph a `overlay` Graph b = Graph (a `G.overlay` b)
    Graph a `connect` Graph b = Graph (a `G.connect` b)

instance Ord a => ALGA.ToGraph (Graph a name) where
    type ToVertex (Graph a name) =  a
    toGraph (Graph g) = ALGA.toGraph g

instance ToDotVertex a => ToDot (Graph a name) where
    exportStyle _ = exportVertexStyle

instance KnownSymbol name => ToSchema (Graph a name) where
    declareNamedSchema _ = pure $ NamedSchema (Just $ fromString $ "Graph" ++ n) mempty
      where
        n = symbolVal (Proxy :: Proxy name)
