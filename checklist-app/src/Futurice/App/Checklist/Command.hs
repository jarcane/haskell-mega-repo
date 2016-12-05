{-# LANGUAGE DataKinds            #-}
{-# LANGUAGE FlexibleContexts     #-}
{-# LANGUAGE KindSignatures       #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE RankNTypes           #-}
{-# LANGUAGE TemplateHaskell      #-}
{-# LANGUAGE TypeFamilies         #-}
{-# LANGUAGE TypeOperators        #-}
{-# LANGUAGE UndecidableInstances #-}
module Futurice.App.Checklist.Command (
    -- * Command
    Command (..),
    traverseCommand,
    applyCommand,
    transactCommand,
    -- * Edits
    TaskEdit (..),
    applyTaskEdit,
    ) where

import Prelude ()
import Futurice.Prelude
import Data.Aeson.Compat
       (Parser, object, withObject, (.!=), (.:), (.:?), (.=))
import Futurice.Generics
import Futurice.IsMaybe

import qualified Control.Lens               as Lens
import qualified Database.PostgreSQL.Simple as Postgres
import qualified Generics.SOP               as SOP

import Futurice.App.Checklist.Types

-------------------------------------------------------------------------------
-- Edit types
-------------------------------------------------------------------------------

data TaskEdit f = TaskEdit
    { teName :: !(f :$ Name Task)
    , teRole :: !(f TaskRole)
    }

deriveGeneric ''TaskEdit

applyTaskEdit :: TaskEdit Maybe -> Task -> Task
applyTaskEdit te
    = maybe id (Lens.set taskName) (teName te)
    . maybe id (Lens.set taskRole) (teRole te)

instance Eq1 f => Eq (TaskEdit f) where
    TaskEdit n r == TaskEdit n' r' = eq1 n n' && eq1 r r'

instance Show1 f => Show (TaskEdit f) where
    showsPrec d (TaskEdit n r) = showsBinaryWith
        showsPrec1 showsPrec1
        "TaskEdit" d n r

instance SOP.All (SOP.Compose Arbitrary f) '[Name Task, TaskRole]
    => Arbitrary (TaskEdit f)
  where
    arbitrary = sopArbitrary
    shrink = sopShrink

instance
    ( SOP.All (SOP.Compose ToJSON f) '[Name Task, TaskRole]
    , SOP.All (SOP.Compose IsMaybe f) '[Name Task, TaskRole]
    )
    => ToJSON (TaskEdit f)
  where
    toJSON = sopToJSON
    toEncoding = sopToEncoding

instance
    ( SOP.All (SOP.Compose FromJSON f) '[Name Task, TaskRole]
    , SOP.All (SOP.Compose IsMaybe f) '[Name Task, TaskRole]
    )
    => FromJSON (TaskEdit f)
  where
    parseJSON = sopParseJSON

-------------------------------------------------------------------------------
-- Command
-------------------------------------------------------------------------------

-- | Command as in CQRS
data Command f
    = CmdCreateChecklist (f :$ Identifier Checklist) (Name Checklist)
    | CmdRenameChecklist (Identifier Checklist) (Name Checklist)
    | CmdCreateTask (f :$ Identifier Task) (TaskEdit Identity)
    | CmdEditTask (Identifier Task) (TaskEdit Maybe)
    | CmdAddTask (Identifier Checklist) (Identifier Task) TaskAppliance

deriveGeneric ''Command

traverseCommand
    :: Applicative m
    => (forall x. f (Identifier x) -> m (g (Identifier x)))
    -> Command f
    -> m (Command g)
traverseCommand  f (CmdCreateChecklist i n) =
    CmdCreateChecklist <$> f i <*> pure n
traverseCommand _f (CmdRenameChecklist i n) =
    pure $ CmdRenameChecklist i n
traverseCommand  f (CmdCreateTask i e) =
    CmdCreateTask <$> f i <*> pure e
traverseCommand _f (CmdEditTask i e) =
    pure $ CmdEditTask i e
traverseCommand _f (CmdAddTask c t a) =
    pure $ CmdAddTask c t a

-- todo: in error monad, if e.g. identifier don't exist
applyCommand :: Command Identity -> World -> World
applyCommand _ = id

transactCommand :: Postgres.Connection -> Command Identity -> IO ()
transactCommand _ _ = pure ()

instance Eq1 f => Eq (Command f) where
    CmdCreateChecklist cid n == CmdCreateChecklist cid' n'
        = eq1 cid cid' && n == n'
    CmdRenameChecklist cid n == CmdRenameChecklist cid' n'
        = cid == cid' && n == n'
    CmdCreateTask tid te == CmdCreateTask tid' te'
        = eq1 tid tid' && te == te'
    CmdEditTask tid te == CmdEditTask tid' te'
        = tid == tid' && te == te'
    CmdAddTask cid tid app == CmdAddTask cid' tid' app'
        = cid == cid' && tid == tid' && app == app'

    -- Otherwise false
    _ == _ = False

instance Show1 f => Show (Command f) where
    showsPrec d (CmdCreateChecklist i n) = showsBinaryWith
        showsPrec1 showsPrec
        "CmdCreateChecklist" d i n
    showsPrec d (CmdRenameChecklist i n) = showsBinaryWith
        showsPrec showsPrec
        "CmdRenameChecklist" d i n
    showsPrec d (CmdCreateTask i te) = showsBinaryWith
        showsPrec1 showsPrec
        "CmdCreateTask" d i te
    showsPrec d (CmdEditTask i te) = showsBinaryWith
        showsPrec showsPrec
        "CmdEditTask" d i te
    showsPrec d (CmdAddTask c t a) = showsTernaryWith
        showsPrec showsPrec showsPrec
        "CmdAddTask" d c t a

instance SOP.All (SOP.Compose Arbitrary f) '[Identifier Checklist, Identifier Task]
    => Arbitrary (Command f)
  where
    arbitrary = sopArbitrary
    shrink = sopShrink

-- | This and 'ParseJSON' instance is written by hand, as 'sopToJSON' and friends
-- work with records only, and we want field names!
instance SOP.All (SOP.Compose ToJSON f) '[Identifier Checklist, Identifier Task]
    => ToJSON (Command f)
  where
    toJSON (CmdCreateChecklist cid n) = object
        [ "cmd"  .= ("create-checklist" :: Text)
        , "cid"  .= cid
        , "name" .= n
        ]
    toJSON (CmdRenameChecklist cid n) = object
        [ "cmd"  .= ("rename-checklist" :: Text)
        , "cid"  .= cid
        , "name" .= n
        ]
    toJSON (CmdCreateTask tid te) = object
        [ "cmd"  .= ("create-task" :: Text)
        , "tid"  .= tid
        , "edit" .= te
        ]
    toJSON (CmdEditTask tid te) = object
        [ "cmd"  .= ("edit-task" :: Text)
        , "tid"  .= tid
        , "edit" .= te
        ]
    toJSON (CmdAddTask cid tid TaskApplianceAll) = object
        [ "cmd"       .= ("add-task" :: Text)
        , "cid"       .= cid
        , "tid"       .= tid
        -- , "appliance" .= app
        ]

    -- toEncoding

instance SOP.All (SOP.Compose FromJSON f) '[Identifier Checklist, Identifier Task]
    => FromJSON (Command f)
  where
    parseJSON = withObject "Command" $ \obj -> do
        cmd <- obj .: "cmd" :: Parser Text
        case cmd of
            "create-checklist" -> CmdCreateChecklist
                <$> obj .: "cid"
                <*> obj .: "name"
            "rename-checklist" -> CmdRenameChecklist
                <$> obj .: "cid"
                <*> obj .: "name"
            "create-task" -> CmdCreateTask
                <$> obj .: "tid"
                <*> obj .: "edit"
            "edit-task" -> CmdEditTask
                <$> obj .: "tid"
                <*> obj .: "edit"
            "add-task" -> CmdAddTask
                <$> obj .: "cid"
                <*> obj .: "tid"
                <*> obj .:? "appliance" .!= TaskApplianceAll
            _ -> fail $ "Invalid Command tag " ++ cmd ^. unpacked
