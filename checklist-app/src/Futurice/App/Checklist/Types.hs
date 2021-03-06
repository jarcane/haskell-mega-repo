{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeFamilies      #-}
{-# LANGUAGE TypeOperators     #-}
-- | Types employee in checklist logic.
--
-- Currently missing:
--
-- * How to model construction and modification of 'CheckList'. We want to pick
--   only needed 'Task's based on initial 'Employee' data, and that information
--   should be configurable dynamically.
module Futurice.App.Checklist.Types (
    -- * Core types
    -- ** Employee / employee
    Employee(..),
    EmployeeId,
    ContractType(..),
    -- ** Tasks
    Task(..),
    TaskId,
    TaskRole(..),
    CheckResult(..),
    Checklist(..),
    ChecklistId (..),
    PerChecklist (..),
    TaskItem (..),
    AnnTaskItem (..),
    TaskAppliance(..),
    TaskComment(..),
    TaskTag(..),
    PMUser(..),
    -- ** Wrappers
    Identifier(..),
    identifierToText,
    HasIdentifier (..),
    identifierText,
    Name (..),
    HasName (..),
    IntegrationData (..),
    -- * Functions
    employeeTaskApplies,
    -- * Lenses
    -- ** Employee
    employeeFirstName, employeeLastName, employeeContractType, employeeOffice, employeeConfirmed,
    employeePhone, employeeContactEmail, employeeStartingDay, employeeSupervisor, employeeTribe,
    employeeInfo, employeeFUMLogin, employeeHRNumber, employeeChecklist, employeePersonio,
    -- ** ContractType
    _ContractType,
    _ContractTypePermanent, _ContractTypeExternal, _ContractTypeFixedTerm,
    _ContractTypePartTimer, _ContractTypeSummerWorker,
    contractTypeToText,
    -- ** Task
    taskName, taskInfo, taskPrereqs, taskRole, taskComment, taskTags, taskOffset, taskApplicability,
    -- ** TaskNode
    TaskNode (..), taskNode,
    -- ** CheckResult
    _CheckResultSuccess, _CheckResultMaybe, _CheckResultFailure,
    -- ** TaskRole
    _TaskRole,
    _TaskRoleIT, _TaskRoleHR, _TaskRoleSupervisor,
    taskRoleToText, taskRoleFromText,
    PerTaskRole (..),
    -- ** TaskTag
    _TaskTag,
    taskTagToText, taskTagFromText,
    -- ** Checklist
    _ChecklistId,
    checklistId, checklistIdName, checklistName, checklistTasks,
    -- ** TaskItem
    _TaskItem,
    _TaskItemDone, _TaskItemTodo,
    -- ** AnnTaskItem
    annTaskItemTodo,
    annTaskItemComment,
    _AnnTaskItemDone, _AnnTaskItemTodo,
    -- ** IntegrationData
    githubData, personioData, planmillData,
    -- * World
    World,
    emptyWorld,
    mkWorld,
    ArchivedEmployee (..),
    archiveEmployee,
    -- ** Lenses
    worldEmployees,
    worldArchive,
    worldTasks,
    worldLists,
    worldTaskItems,
    worldTaskItems',
    worldTasksSorted,
    worldTasksSortedByName,
    tasksSorted,
    -- * Access
    AuthUser,
    authUserTaskRole,
    -- * Counters
    Counter (..),
    TodoCounter (..),
    toTodoCounter,
    taskItemtoTodoCounter,
    -- * Helpers
    SortCriteria (..),
    -- * Re-exports
    module Futurice.Office,
    module Futurice.Tribe,
    ) where

import Futurice.Office
import Futurice.Prelude
import Futurice.Tribe
import Prelude ()

import Futurice.App.Checklist.Types.Basic
import Futurice.App.Checklist.Types.ChecklistId
import Futurice.App.Checklist.Types.ContractType
import Futurice.App.Checklist.Types.Counter
import Futurice.App.Checklist.Types.Identifier
import Futurice.App.Checklist.Types.SortCriteria
import Futurice.App.Checklist.Types.TaskAppliance
import Futurice.App.Checklist.Types.TaskComment
import Futurice.App.Checklist.Types.TaskItem
import Futurice.App.Checklist.Types.TaskRole
import Futurice.App.Checklist.Types.TaskTag
import Futurice.App.Checklist.Types.World

import qualified FUM.Types.Login as FUM (Login)

type AuthUser = (FUM.Login, TaskRole)

authUserTaskRole :: Lens' AuthUser TaskRole
authUserTaskRole = _2
