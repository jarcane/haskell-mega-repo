{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}
module Futurice.App.FUM.Pages.ViewGroup (viewGroupPage) where

import Futurice.Prelude
import Prelude ()

import Futurice.App.FUM.ACL
import Futurice.App.FUM.Command
import Futurice.App.FUM.Lomake
import Futurice.App.FUM.Markup
import Futurice.App.FUM.Types

viewGroupPage
    :: AuthUser
    -> World  -- ^ the world
    -> Group  -- ^ group
    -> HtmlPage "view-group"
viewGroupPage auth world g = fumPage_ "Group" auth $ do
    -- Title
    fumHeader_ "Group" [g ^? groupName . getter groupNameToText ]

    fullRow_ $ table_ $ tbody_ $ do
        vertRow_ "Name" $ toHtml $ g ^. groupName
        vertRow_ "Type" $ toHtml $ g ^. groupType

    when (canEditGroup (authLogin auth) (g ^. groupName) world) $ do
        block_ "Add member" $ commandHtml' (Proxy :: Proxy AddEmployeeToGroup) $
            vHidden (g ^. groupName) :*
            vEmployees (\e -> notElem e $ g ^.. groupEmployees . folded) world :*
            Nil

    block_ "Members" $ do
        fullRow_ $ table_ $ do
            thead_ $ tr_ $ do
                th_ "Login"
                th_ "Name"
                th_ "Status"

            tbody_ $ for_ (g ^.. groupEmployees . folded) $ \login -> tr_ $
                for_ (world ^? worldEmployees . ix login) $ \e -> do
                    td_ $ loginToHtml $ e ^. employeeLogin
                    td_ $ toHtml $ e ^. employeeName
                    td_ $ toHtml $ e ^. employeeStatus

        todos_ ["Removal of member, edit group type, remove group, special (e.g. office) groups"]
