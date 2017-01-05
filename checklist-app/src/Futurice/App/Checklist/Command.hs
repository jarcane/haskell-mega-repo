{-# LANGUAGE CPP                  #-}
{-# LANGUAGE DataKinds            #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE FlexibleContexts     #-}
{-# LANGUAGE KindSignatures       #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE RankNTypes           #-}
{-# LANGUAGE RecordWildCards      #-}
{-# LANGUAGE TemplateHaskell      #-}
{-# LANGUAGE TypeFamilies         #-}
{-# LANGUAGE TypeOperators        #-}
{-# LANGUAGE UndecidableInstances #-}
#if __GLASGOW_HASKELL__ >= 800
{-# OPTIONS_GHC -fconstraint-solver-iterations=0 #-}
#endif

module Futurice.App.Checklist.Command (
    -- * Command
    Command (..),
    traverseCommand,
    CIT (..),
    applyCommand,
    transactCommand,
    -- * Edits
    TaskEdit (..),
    applyTaskEdit,
    EmployeeEdit (..),
    fromEmployeeEdit,
    applyEmployeeEdit,
    ) where

import Prelude ()
import Futurice.Prelude
import Control.Lens               (iforOf_, non)
import Control.Monad.State.Strict (execState)
import Data.Swagger               (NamedSchema (..))
import Futurice.Aeson
       (FromJSONField1, fromJSONField1, object, withObject, (.!=), (.:), (.:?),
       (.=))
import Futurice.Generics
import Futurice.IsMaybe

import qualified Control.Lens                         as Lens
import qualified Data.Aeson.Compat                    as Aeson
import qualified Database.PostgreSQL.Simple           as Postgres
import qualified Database.PostgreSQL.Simple.FromField as Postgres
import qualified Database.PostgreSQL.Simple.ToField   as Postgres
import qualified FUM
import qualified Generics.SOP                         as SOP

import Futurice.App.Checklist.Types

-------------------------------------------------------------------------------
-- Task edit
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
-- Employee edit
-------------------------------------------------------------------------------

data EmployeeEdit f = EmployeeEdit
    { eeFirstName    :: !(f Text)
    , eeLastName     :: !(f Text)
    , eeContractType :: !(f ContractType)
    , eeLocation     :: !(f Location)
    , eeConfirmed    :: !(f Bool)
    , eeStartingDay  :: !(f Day)
    , eeSupervisor   :: !(f FUM.UserName)
    , eeTribe        :: !(f Text)
    , eeInfo         :: !(f Text)
    -- this fields are optional
    , eePhone        :: !(Maybe Text)
    , eeContactEmail :: !(Maybe Text)
    , eeFUMLogin     :: !(Maybe FUM.UserName)
    , eeHRNumber     :: !(Maybe Int)
    }

deriveGeneric ''EmployeeEdit

fromEmployeeEdit
    :: Identifier Employee
    -> Identifier Checklist
    -> EmployeeEdit Identity
    -> Employee
fromEmployeeEdit eid cid EmployeeEdit {..} = Employee
    { _employeeId           = eid
    , _employeeChecklist    = cid
    , _employeeFirstName    = runIdentity eeFirstName
    , _employeeLastName     = runIdentity eeLastName
    , _employeeContractType = runIdentity eeContractType
    , _employeeLocation     = runIdentity eeLocation
    , _employeeConfirmed    = runIdentity eeConfirmed
    , _employeeStartingDay  = runIdentity eeStartingDay
    , _employeeSupervisor   = runIdentity eeSupervisor
    , _employeeTribe        = runIdentity eeTribe
    , _employeeInfo         = runIdentity eeInfo
    , _employeePhone        = eePhone
    , _employeeContactEmail = eeContactEmail
    , _employeeFUMLogin     = eeFUMLogin
    , _employeeHRNumber     = eeHRNumber
    }

applyEmployeeEdit :: EmployeeEdit Maybe -> Employee -> Employee
applyEmployeeEdit ee
    = maybe id (Lens.set employeeFirstName) (eeFirstName ee)
    . maybe id (Lens.set employeeLastName) (eeLastName ee)

instance Eq1 f => Eq (EmployeeEdit f) where
    a == b
        = eq1 (eeFirstName a) (eeFirstName b)
        && eq1 (eeLastName a) (eeLastName b)
        && eq1 (eeContractType a) (eeContractType b)

instance Show1 f => Show (EmployeeEdit f) where
    showsPrec d EmployeeEdit {..} = showParen (d > 10)
        $ showString "EmployeeEdit"
        . showChar ' ' . showsPrec1 11 eeFirstName
        . showChar ' ' . showsPrec1 11 eeLastName

type EmployeeEditFieldTypes =
    '[Text, ContractType, Location, Bool, FUM.UserName, Int, Day]

instance SOP.All (SOP.Compose Arbitrary f) EmployeeEditFieldTypes
    => Arbitrary (EmployeeEdit f)
  where
    arbitrary = sopArbitrary
    shrink = sopShrink

instance
    ( SOP.All (SOP.Compose ToJSON f) EmployeeEditFieldTypes
    , SOP.All (SOP.Compose IsMaybe f) EmployeeEditFieldTypes
    )
    => ToJSON (EmployeeEdit f)
  where
    toJSON = sopToJSON
    toEncoding = sopToEncoding

instance
    ( SOP.All (SOP.Compose FromJSON f) EmployeeEditFieldTypes
    , SOP.All (SOP.Compose IsMaybe f) EmployeeEditFieldTypes
    )
    => FromJSON (EmployeeEdit f)
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
    | CmdRemoveTask (Identifier Checklist) (Identifier Task)
    | CmdCreateEmployee (f :$ Identifier Employee) (Identifier Checklist) (EmployeeEdit Identity)
    | CmdTaskItemToggle (Identifier Employee) (Identifier Task) TaskItem

-- CmdEditEmployee
-- CmdEditTaskAppliance
-- CmdArchiveEmployee

deriveGeneric ''Command

data CIT a where
    CITTask      :: CIT Task
    CITEmployee  :: CIT Employee
    CITChecklist :: CIT Checklist

traverseCommand
    :: Applicative m
    => (forall x. CIT x -> f (Identifier x) -> m (g (Identifier x)))
    -> Command f
    -> m (Command g)
traverseCommand  f (CmdCreateChecklist i n) =
    CmdCreateChecklist <$> f CITChecklist i <*> pure n
traverseCommand _f (CmdRenameChecklist i n) =
    pure $ CmdRenameChecklist i n
traverseCommand f (CmdCreateTask i e) =
    CmdCreateTask <$> f CITTask i <*> pure e
traverseCommand _f (CmdEditTask i e) =
    pure $ CmdEditTask i e
traverseCommand _f (CmdAddTask c t a) =
    pure $ CmdAddTask c t a
traverseCommand _f (CmdRemoveTask c t) =
    pure $ CmdRemoveTask c t
traverseCommand f (CmdCreateEmployee e c x) =
    CmdCreateEmployee <$> f CITEmployee e <*> pure c <*> pure x
traverseCommand _ (CmdTaskItemToggle e t x) =
    pure $ CmdTaskItemToggle e t x

-- = operators are the same as ~ lens operators, but modify the state of MonadState.
--
-- todo: in error monad, if e.g. identifier don't exist
applyCommand :: Command Identity -> World -> World
applyCommand cmd world = flip execState world $ case cmd of
    CmdCreateChecklist (Identity cid) n ->
        worldLists . at cid ?= Checklist cid n mempty

    CmdCreateTask (Identity tid) (TaskEdit (Identity n) (Identity role)) ->
        worldTasks . at tid ?= Task tid n mempty role

    CmdAddTask cid tid app ->
        worldLists . ix cid . checklistTasks . at tid ?= app
        -- TODO: add to worldTaskItems

    CmdRemoveTask cid tid ->
        worldLists . ix cid . checklistTasks . at tid Lens..= Nothing

    CmdRenameChecklist cid n ->
         worldLists . ix cid . checklistName Lens..= n

    CmdEditTask tid te ->
        worldTasks . ix tid %= applyTaskEdit te

    CmdCreateEmployee (Identity eid) cid x -> do
        -- create user
        worldEmployees . at eid ?= fromEmployeeEdit eid cid x
        -- add initial tasks
        iforOf_ (worldLists . ix cid . checklistTasks . ifolded) world $ \tid _app ->
            -- TODO: check appliance before adding
            worldTaskItems . at eid . non mempty . at tid ?= TaskItemTodo

    CmdTaskItemToggle eid tid d ->
        worldTaskItems . ix eid . ix tid Lens..= d

transactCommand
    :: (MonadLog m, MonadIO m)
    => Postgres.Connection -> FUM.UserName -> Command Identity -> m ()
transactCommand conn ssoUser cmd = do
    logInfo "transactCommand" cmd
    _ <- liftIO $ Postgres.execute conn
        "INSERT INTO checklist2.commands (username, cmddata) VALUES (?, ?)"
        (ssoUser, cmd)
    pure ()

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
    CmdRemoveTask cid tid == CmdRemoveTask cid' tid'
        = cid == cid' && tid == tid'
    CmdCreateEmployee eid cid x == CmdCreateEmployee eid' cid' x'
        = eq1 eid eid' && cid == cid' && x == x'
    CmdTaskItemToggle eid tid d == CmdTaskItemToggle eid' tid' d'
        = eid == eid' && tid == tid' && d == d'

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
    showsPrec d (CmdRemoveTask c t) = showsBinaryWith
        showsPrec showsPrec
        "CmdRemoveTask" d c t
    showsPrec d (CmdCreateEmployee e c x) = showsTernaryWith
        showsPrec1 showsPrec showsPrec
        "CmdCreateEmployee" d e c x
    showsPrec d (CmdTaskItemToggle e t done) = showsTernaryWith
        showsPrec showsPrec showsPrec
        "CmdTaskItemToggle" d e t done

instance SOP.All (SOP.Compose Arbitrary f) '[Identifier Checklist, Identifier Task, Identifier Employee]
    => Arbitrary (Command f)
  where
    arbitrary = sopArbitrary
    shrink = sopShrink

-- | This and 'ParseJSON' instance is written by hand, as 'sopToJSON' and friends
-- work with records only, and we want field names!
instance SOP.All (SOP.Compose ToJSON f) '[Identifier Checklist, Identifier Task, Identifier Employee]
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
    toJSON (CmdRemoveTask cid tid) = object
        [ "cmd"       .= ("remove-task" :: Text)
        , "cid"       .= cid
        , "tid"       .= tid
        ]
    toJSON (CmdCreateEmployee eid cid x) = object
        [ "cmd"  .= ("create-employee" :: Text)
        , "eid"  .= eid
        , "cid"  .= cid
        , "edit" .= x
        ]
    toJSON (CmdTaskItemToggle eid tid done) = object
        [ "cmd"  .= ("task-item-toggle" :: Text)
        , "eid"  .= eid
        , "tid"  .= tid
        , "done" .= done
        ]

    -- toEncoding

instance FromJSONField1 f => FromJSON (Command f)
  where
    parseJSON = withObject "Command" $ \obj -> do
        cmd <- obj .: "cmd" :: Aeson.Parser Text
        case cmd of
            "create-checklist" -> CmdCreateChecklist
                <$> fromJSONField1 obj "cid"
                <*> obj .: "name"
            "rename-checklist" -> CmdRenameChecklist
                <$> obj .: "cid"
                <*> obj .: "name"
            "create-task" -> CmdCreateTask
                <$> fromJSONField1 obj "tid"
                <*> obj .: "edit"
            "edit-task" -> CmdEditTask
                <$> obj .: "tid"
                <*> obj .: "edit"
            "add-task" -> CmdAddTask
                <$> obj .: "cid"
                <*> obj .: "tid"
                <*> obj .:? "appliance" .!= TaskApplianceAll
            "remove-task" -> CmdRemoveTask
                <$> obj .: "cid"
                <*> obj .: "tid"
            "create-employee" -> CmdCreateEmployee
                <$> fromJSONField1 obj "eid"
                <*> obj .: "cid"
                <*> obj .: "edit"
            "task-item-toggle" -> CmdTaskItemToggle
                <$> obj .: "eid"
                <*> obj .: "tid"
                <*> obj .: "done"

            _ -> fail $ "Invalid Command tag " ++ cmd ^. unpacked

-- TODO
instance ToSchema (Command p) where
    declareNamedSchema _ = pure $ NamedSchema (Just "Command") mempty

instance SOP.All (SOP.Compose ToJSON f) '[Identifier Checklist, Identifier Task, Identifier Employee]
    => Postgres.ToField (Command f)
  where
    toField = Postgres.toField . Aeson.encode

instance FromJSONField1 f => Postgres.FromField (Command f) where
    fromField f mdata = do
        bs <- Postgres.fromField f mdata
        case Aeson.eitherDecode bs of
            Right x  -> pure x
            Left err -> Postgres.conversionError (Aeson.AesonException err)