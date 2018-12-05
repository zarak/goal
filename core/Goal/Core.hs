{-# LANGUAGE ExplicitNamespaces #-}

-- | This is the base module of @goal-core@, and is the only module that should be imported in order
-- to use the functionality provided in this library.
module Goal.Core
    ( -- * Module Exports
      module Goal.Core.Util
    , module Goal.Core.Project
    , module Goal.Core.HList
    , module Data.Function
    , module Data.Functor
    , module Data.Foldable
    , module Data.Traversable
    , module Data.Ord
    , module Data.Maybe
    , module Data.Either
    , module Data.Finite
    , module Data.Csv
    , module Data.Proxy
    , module Data.Kind
    , module Control.Applicative
    , module Control.Monad
    , module Control.Monad.Primitive
    , module Control.Monad.ST
    , module Control.Arrow
    , module Control.Concurrent
    , module Control.DeepSeq
    , module Numeric
    , module Numeric.SpecFunctions
    , module Options.Applicative
    , module GHC.TypeNats
    , module GHC.Generics
    , module Debug.Trace
    , module System.Directory
    , NatNumber
    ) where


--- Imports ---


-- Re-exports --

import Goal.Core.Util
import Goal.Core.Project
import Goal.Core.HList

import Data.Csv hiding (Parser,header,Field)
import Data.Functor
import Data.Foldable
import Data.Traversable
import Data.Ord
import Data.Function hiding ((&))
import Data.Maybe
import Data.Either
import Data.Proxy
import Data.Finite
import Data.Kind

import Control.Applicative hiding (empty)
import Control.Arrow hiding ((<+>))
import Control.Monad
import Control.Monad.ST
import Control.Concurrent
import Control.DeepSeq hiding (force)
import Control.Monad.Primitive hiding (internal)

import Options.Applicative

import GHC.TypeNats hiding (Mod)
import GHC.Generics (Generic)

import Debug.Trace
import System.Directory
import Numeric hiding (log1p,expm1)
import Numeric.SpecFunctions

import Numeric.Natural

type NatNumber = Natural
