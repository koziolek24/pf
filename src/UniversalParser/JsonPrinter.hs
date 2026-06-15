{-# LANGUAGE OverloadedStrings #-}

module UniversalParser.JsonPrinter where

import Data.List (intercalate)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import Numeric (showHex)
import UniversalParser.AST

toJson :: UniversalValue -> String
toJson v = renderValue 0 v

indent :: Int -> String
indent n = replicate (n * 2) ' '

renderValue :: Int -> UniversalValue -> String
renderValue _ VNull = "null"
renderValue _ (VBool True) = "true"
renderValue _ (VBool False) = "false"
renderValue _ (VInt n) = show n
renderValue _ (VFloat d) = show d
renderValue _ (VString t) = renderString t
renderValue lvl (VArray vs) = renderArray lvl vs
renderValue lvl (VObject m) = renderObject lvl m
renderValue lvl (VElement tag attrs children) =
  renderElement lvl tag attrs children

renderString :: Text -> String
renderString t = "\"" ++ escape (T.unpack t) ++ "\""
  where
    escape [] = []
    escape ('"' : cs) = '\\' : '"' : escape cs
    escape ('\\' : cs) = '\\' : '\\' : escape cs
    escape ('\n' : cs) = '\\' : 'n' : escape cs
    escape ('\r' : cs) = '\\' : 'r' : escape cs
    escape ('\t' : cs) = '\\' : 't' : escape cs
    escape (c : cs)
      | c < '\x20' = "\\u" ++ pad4 (showHex (fromEnum c) "") ++ escape cs
      | otherwise = c : escape cs
    pad4 s = replicate (4 - length s) '0' ++ s

renderArray :: Int -> [UniversalValue] -> String
renderArray _ [] = "[]"
renderArray lvl vs =
  "[\n"
    ++ intercalate ",\n" (map renderItem vs)
    ++ "\n"
    ++ indent lvl
    ++ "]"
  where
    renderItem v = indent (lvl + 1) ++ renderValue (lvl + 1) v

renderObject :: Int -> Map Text UniversalValue -> String
renderObject _ m | Map.null m = "{}"
renderObject lvl m =
  "{\n"
    ++ intercalate ",\n" (map renderPair (Map.toAscList m))
    ++ "\n"
    ++ indent lvl
    ++ "}"
  where
    renderPair (k, v) =
      indent (lvl + 1) ++ renderString k ++ ": " ++ renderValue (lvl + 1) v

renderElement :: Int -> Text -> Map Text Text -> [UniversalValue] -> String
renderElement lvl tag attrs children =
  renderObject lvl $
    Map.fromList
      [ ("_tag", VString tag),
        ("_attrs", VObject (Map.map VString attrs)),
        ("_children", VArray children)
      ]
