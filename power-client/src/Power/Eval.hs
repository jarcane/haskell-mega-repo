{-# LANGUAGE GADTs             #-}
{-# LANGUAGE OverloadedStrings #-}
module Power.Eval (
    evalIO,
    evalIOReq,
    ) where

import Control.Monad.Free
import Futurice.Prelude
import Network.HTTP.Types                 (statusCode)
import Prelude ()
import Servant.Client
import Servant.Client.Free
import Servant.Client.Generic
import Servant.Client.Internal.HttpClient
       (catchConnectionError, clientResponseToResponse, requestToClientRequest)

import qualified Network.HTTP.Client as HTTP

import Power.API
import Power.Request

routes :: PowerRoutes (AsClientT ClientM)
routes = genericClient

evalIO :: BaseUrl -> Manager -> Req a -> IO (Either ServantError a)
evalIO burl mgr req = case req of
    ReqPeople -> runClientM (routePeople routes) env
  where
    env = mkClientEnv mgr burl

freeRoutes :: PowerRoutes (AsClientT (Free ClientF))
freeRoutes = genericClient

-- | We essentially implement own servant-client library.
evalIOReq :: HTTP.Request -> Manager -> Req a -> IO (Either ServantError a)
evalIOReq baseReq mgr req = runExceptT $ case req of
    ReqPeople -> foldFree act (routePeople freeRoutes)
  where
    act :: ClientF x -> ExceptT ServantError IO x
    act (Throw err)             = throwError err
    act (StreamingRequest _ _ ) = throwError $ ConnectionError "cannot stream"
    act (RunRequest sReq sRes)  = do
        let httpReq = amendRequest (requestToClientRequest burl sReq)
        httpRes <- liftIO $ catchConnectionError $ HTTP.httpLbs httpReq mgr
        case httpRes of
            Left err -> throwError err
            Right response' -> do
                let status = HTTP.responseStatus response
                    status_code = statusCode status
                    response = response' { HTTP.responseHeaders = mapResHeaders (HTTP.responseHeaders response') }
                    ourResponse = clientResponseToResponse response
                unless (status_code >= 200 && status_code < 300) $
                    throwError $ FailureResponse ourResponse
                return (sRes ourResponse)

    burl = BaseUrl
        { baseUrlScheme = if HTTP.port baseReq == 443 then Https else Http
        , baseUrlHost   = decodeUtf8Lenient (HTTP.host baseReq) ^. unpacked
        , baseUrlPort   = HTTP.port baseReq
        , baseUrlPath   = decodeUtf8Lenient (HTTP.path baseReq) ^. unpacked
        }

    amendRequest :: HTTP.Request -> HTTP.Request
    amendRequest r = r
        { HTTP.requestHeaders = HTTP.requestHeaders r ++ HTTP.requestHeaders baseReq
        , HTTP.responseTimeout = HTTP.responseTimeout baseReq
        }

    mapResHeaders = map f where
        f (h@"Content-Type", _) = (h, "application/json;charset=utf-8")
        f h = h
