{-# LANGUAGE OverloadedStrings #-}

module UniversalParser.AST where

import Data.Map.Strict (Map)
import Data.Text (Text)

data UniversalValue
  = VNull
  | VBool Bool
  | VInt Integer
  | VFloat Double
  | VString Text
  | VArray [UniversalValue]
  | VObject (Map Text UniversalValue)
  | VElement Text (Map Text Text) [UniversalValue]
  deriving (Show, Eq)
