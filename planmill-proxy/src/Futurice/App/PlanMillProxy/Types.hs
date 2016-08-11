module Futurice.App.PlanMillProxy.Types (
    Ctx (..),
    ) where

import Control.Monad.Logger       (LogLevel (..))
import Data.Pool                  (Pool)
import Database.PostgreSQL.Simple (Connection)
import Futurice.Servant           (DynMapCache)
import PlanMill                   (Cfg)

data Ctx = Ctx
    { ctxCache        :: !DynMapCache
    , ctxPlanmillCfg  :: !Cfg
    , ctxPostgresPool :: !(Pool Connection)  -- TODO: write a lib to handle these
    , ctxLogLevel     :: !LogLevel
    }