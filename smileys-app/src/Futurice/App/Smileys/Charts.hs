{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies      #-}
module Futurice.App.Smileys.Charts where

import Control.Lens      ((.=))
import Data.Distributive (Distributive (..))
import Data.Functor.Rep  (Representable (..), distributeRep)
import Futurice.Cache    (cached)
import Futurice.Postgres
import Futurice.Prelude
import GHC.TypeLits      (KnownSymbol, symbolVal)
import Prelude ()
import Servant           (Handler)
import Servant.Chart     (Chart (..))

import Futurice.App.Smileys.Ctx
import Futurice.App.Smileys.Types

import qualified Data.Map                      as Map
import qualified Graphics.Rendering.Chart.Easy as C

import Futurice.Chart.Stacked as C

-------------------------------------------------------------------------------
-- Absolute
-------------------------------------------------------------------------------

absoluteChartHandler :: Ctx -> Handler (Chart "absolute")
absoluteChartHandler = chartHandler chart
  where
    chart values = Chart . C.toRenderable $ do
        C.layout_title .= "absolute smileys per day"
        C.layout_x_axis . C.laxis_title .= "day"
        C.layout_y_axis . C.laxis_title .= "smileys count"

        C.plot $ fmap C.stackedToPlot $ C.stacked
            (SmileyAcc ":(" ":|" ":)")
            (Map.toList values)

-------------------------------------------------------------------------------
-- Relative
-------------------------------------------------------------------------------

relativeChartHandler :: Ctx -> Handler (Chart "relative")
relativeChartHandler = chartHandler chart
  where
    chart values = Chart . C.toRenderable $ do
        C.layout_title .= "absolute smileys per day"
        C.layout_x_axis . C.laxis_title .= "day"
        C.layout_y_axis . C.laxis_title .= "smileys count"

        C.plot $ fmap C.stackedToPlot $ C.stacked
            (SmileyAcc ":(" ":|" ":)")
            (Map.toList $ fmap scale values)

    scale (SmileyAcc x y z)
        | s > 0     = SmileyAcc (x/s) (y/s) (z/s)
        | otherwise = SmileyAcc 0 1 0
      where
        s = x + y + z

-------------------------------------------------------------------------------
-- Common
-------------------------------------------------------------------------------

chartHandler
    :: forall a. KnownSymbol a
    => (Map Day (SmileyAcc Double) -> Chart a)
    -> Ctx -> Handler (Chart a)
chartHandler chart ctx = liftIO $ runLogT "chart" (ctxLogger ctx) $ do
    xs <- cached (ctxCache ctx) 600 (symbolVal (Proxy :: Proxy a)) $ do
        input <- safePoolQuery_ ctx $ fromString $ unwords
            [ "SELECT day, smiley"
            , "FROM smileys.trail"
            , "WHERE"
            , "  (current_timestamp - day + '1 month' :: interval <= '3 months' :: interval)"
            , "  AND GREATEST(day - created, created - day) < '9 days' :: interval"
            ]

        pure $ Map.fromListWith (<>) $ fmap (second smileyAcc) input

    pure (chart xs)

-------------------------------------------------------------------------------
-- Smiley accumulator (per day)
-------------------------------------------------------------------------------

data SmileyAcc a = SmileyAcc !a !a !a
  deriving (Functor, Foldable, Traversable)

instance NFData (SmileyAcc a) where
    rnf (SmileyAcc _ _ _) = ()

data SV = Sad | Normal | Happy

instance Distributive SmileyAcc where
    distribute = distributeRep

instance Representable SmileyAcc where
    type Rep SmileyAcc = SV

    tabulate f = SmileyAcc (f Sad) (f Normal) (f Happy)
    index (SmileyAcc x _ _) Sad    = x
    index (SmileyAcc _ x _) Normal = x
    index (SmileyAcc _ _ x) Happy  = x

instance Num a => Semigroup (SmileyAcc a) where
    SmileyAcc a b c <> SmileyAcc x y z = SmileyAcc (a + x) (b + y) (c + z)

instance Num a=> Monoid (SmileyAcc a) where
    mempty = SmileyAcc 0 0 0
    mappend = (<>)

smileyAcc :: SmileyValue -> SmileyAcc Double
smileyAcc (SmileyValue 0) = SmileyAcc 1 0 0
smileyAcc (SmileyValue 1) = SmileyAcc 0 1 0
smileyAcc (SmileyValue 2) = SmileyAcc 0 0 1
smileyAcc (SmileyValue _) = SmileyAcc 0 0 0
