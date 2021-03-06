{-# LANGUAGE DataKinds     #-}
{-# LANGUAGE TypeOperators #-}
module Futuqu (
    futuquServer,
    FutuquIntegrations,
    module Futuqu.API,
    module Futuqu.Rada.Accounts,
    module Futuqu.Rada.Capacities,
    module Futuqu.Rada.People,
    module Futuqu.Rada.Projects,
    module Futuqu.Rada.Tasks,
    ) where

import Futurice.Cache         (Cache, cachedIO)
import Futurice.Integrations
import Futurice.Prelude
import Prelude ()
import Servant.Server
import Servant.Server.Generic

import Futuqu.API
import Futuqu.Ggrr.HourKinds
import Futuqu.Ggrr.MissingHours
import Futuqu.NT
import Futuqu.Rada.Accounts
import Futuqu.Rada.Capacities
import Futuqu.Rada.People
import Futuqu.Rada.Projects
import Futuqu.Rada.Tasks
import Futuqu.Rada.Timereports
import Futuqu.Strm.Capacities
import Futuqu.Strm.Timereports

-- | Integrations used by /Futuqu/.
type FutuquIntegrations = '[ ServPE, ServPM, ServPO ]

-- | Server of futuqu API.
futuquServer
    :: Logger
    -> Manager
    -> Cache
    -> IntegrationsConfig FutuquIntegrations
    -> Server FutuquAPI
futuquServer lgr mgr cache cfg = genericServer FutuquRoutes
    { futuquRoutePeople      = runIntegrations0 peopleData
    , futuquRouteProjects    = runIntegrations1 projectsData
    , futuquRouteAccounts    = runIntegrations0 accountsData
    , futuquRouteTasks       = runIntegrations2 tasksData
    , futuquRouteCapacities  = runIntegrations1 capacitiesData
    , futuquRouteTimereports = runIntegrations1 timereportsData
    -- strm
    , futuquRouteTimereportsStream = \arg1 -> liftIO $ do
          run <- runIntegrationsCached
          timereportsStrm arg1 run
    , futuquRouteCapacitiesStream = \arg1 -> liftIO $ do
          run <- runIntegrationsCached
          capacitiesStrm arg1 run
    -- ggrr
    , futuquRouteMissingHours = runIntegrations1 missingHoursData
    , futuquRouteHourKinds    = runIntegrations1 hourKindsData
    }
  where
    runIntegrations0
        :: (MonadIO m, Typeable a, NFData a)
        => Integrations FutuquIntegrations a
        -> m a
    runIntegrations0 m = liftIO $ cachedIO lgr cache 600 () $ do
        now <- currentTime
        runIntegrations mgr lgr now cfg m

    runIntegrationsCached :: IO (Integrations FutuquIntegrations :~> IO)
    runIntegrationsCached = do
        now <- currentTime
        env <- makeIntegrationsEnv mgr lgr now cfg

        let runner :: Integrations FutuquIntegrations ~> IO
            runner Nothing  m = runIntegrationsWithEnv env m
            runner (Just k) m = cachedIO lgr cache 600 k $ runIntegrationsWithEnv env m

        return $ NT runner

    runIntegrations1
        :: ( MonadIO m, Typeable a, NFData a
           , Eq k1, Hashable k1, Typeable k1
           )
        => (k1 -> Integrations FutuquIntegrations a)
        -> k1 -> m a
    runIntegrations1 m k1 = liftIO $ cachedIO lgr cache 600 k1 $ do
        now <- currentTime
        runIntegrations mgr lgr now cfg (m k1)

    runIntegrations2
        :: ( MonadIO m, Typeable a, NFData a
           , Eq k1, Hashable k1, Typeable k1
           , Eq k2, Hashable k2, Typeable k2
           )
        => (k1 -> k2 -> Integrations FutuquIntegrations a)
        -> k1 -> k2 -> m a
    runIntegrations2 m k1 k2 = liftIO $ cachedIO lgr cache 600 (k1, k2) $ do
        now <- currentTime
        runIntegrations mgr lgr now cfg (m k1 k2)

-- | This checks we have all instances.
-- Otherwise we'll break only when compiling actual users, i.e .reports-app
_ = serve futuquApi undefined
