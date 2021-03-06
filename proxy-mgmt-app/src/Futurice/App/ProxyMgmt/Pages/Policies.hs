{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE TypeApplications  #-}
module Futurice.App.ProxyMgmt.Pages.Policies (policiesPageHandler) where

import Database.PostgreSQL.Simple (Only (..))
import FUM.Types.Login
import Futurice.Constants         (supportEmailHtml)
import Futurice.Generics          (textualToText)
import Futurice.Lomake
import Futurice.Postgres
import Futurice.Prelude
import Prelude ()
import Servant.Links              (fieldLink)

import qualified Data.Map.Strict as Map
import qualified Data.Set        as Set

import Futurice.App.Proxy.API
import Futurice.App.ProxyMgmt.API
import Futurice.App.ProxyMgmt.Commands.AddEndpoint
import Futurice.App.ProxyMgmt.Commands.RemoveEndpoint
import Futurice.App.ProxyMgmt.Ctx
import Futurice.App.ProxyMgmt.Markup
import Futurice.App.ProxyMgmt.Types
import Futurice.App.ProxyMgmt.Utils

policiesPageHandler :: ReaderT (Login, Ctx f) IO (HtmlPage "policies")
policiesPageHandler = do
    (_, ctx) <- ask
    liftIO $ do
        policies <- fetchPolicyEndpoints ctx
        pure $ policiesPage policies

-------------------------------------------------------------------------------
-- Html
-------------------------------------------------------------------------------

policiesPage :: Map PolicyName (Set LenientEndpoint) -> HtmlPage "policies"
policiesPage policies = page_ "Policies" (Just NavPolicies) $ do
    ifor_ policies $ \policyName endpoints -> do
        h2_ $ "Policy " <> textualToText policyName

        h3_ "Endpoints"
        -- list endpoints (also remove)
        table_ [ class_ "transparent futu-button-no-margin"] $ for_ endpoints $ \endpoint -> vertRow_ (textualToText endpoint) $ do
            let fopts = FormOptions "remove-endpoint-form" (fieldLink routeRemoveEndpoint) ("Remove", "warning")
            lomakeHtml (Proxy @RemoveEndpoint) fopts $
                vHidden policyName :*
                vHidden endpoint :*
                Nil

        -- add endpoint
        h3_ "Add endpoint"
        let fopts = FormOptions "add-endpoint-form" (fieldLink routeAddEndpoint) ("Add", "success")
        lomakeHtml (Proxy @AddEndpoint) fopts $
            vHidden policyName :*
            vNothing :*
            Nil

        hr_ []
