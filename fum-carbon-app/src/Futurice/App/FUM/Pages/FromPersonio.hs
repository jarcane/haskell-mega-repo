{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
module Futurice.App.FUM.Pages.FromPersonio (fromPersonioPage) where

import Data.Maybe              (isNothing)
import Futurice.App.FUM.Markup
import Futurice.App.FUM.Types
import Futurice.IdMap          (IdMap)
import Futurice.Prelude
import Prelude ()

import qualified Personio

fromPersonioPage
    :: AuthUser
    -> World                    -- ^ the world
    -> IdMap Personio.Employee  -- ^ employees
    -> HtmlPage "from-personio"
fromPersonioPage auth world es = fumPage_ "FUM" auth $ do
    fumHeader_  "Personio users" []

    fullRow_ $ table_ $ do
        thead_ $ tr_ $ do
            th_ "id"
            th_ "first"
            th_ "last"
            th_ "login"
            th_ "tribe"
            th_ "office"
            th_ "cost-center"
            th_ "hire date"
            th_ "end date"
            th_ "status"
            th_ "create"
        tbody_ $ for_ es $ \Personio.Employee {..} -> tr_ $
            when (isNothing $ _employeeLogin >>= \login -> world ^? worldEmployees . ix login) $ do
                td_ $ toHtml _employeeId
                td_ $ toHtml _employeeFirst
                td_ $ toHtml _employeeLast
                td_ $ traverse_ toHtml _employeeLogin
                td_ $ toHtml _employeeTribe
                td_ $ toHtml _employeeOffice
                td_ $ traverse_ toHtml _employeeCostCenter
                td_ $ traverse_ (toHtml . show) _employeeHireDate
                td_ $ traverse_ (toHtml . show) _employeeEndDate
                td_ $ toHtml _employeeStatus
                td_ $ futuLinkButton_ (createEmployeeHref_ _employeeId) "Create"
