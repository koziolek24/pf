{-# LANGUAGE OverloadedStrings #-}

module UniversalParser.YamlPrinter where

import UniversalParser.AST

-- import Data.List (intercalate)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T

toYaml :: UniversalValue -> String
toYaml v = "---\n" ++ renderValue 0 v ++ "\n"

indent :: Int -> String
indent n = replicate (n * 2) ' '

renderValue :: Int -> UniversalValue -> String
renderValue _ VNull        = "null"
renderValue _ (VBool True)  = "true"
renderValue _ (VBool False) = "false"
renderValue _ (VInt  n)    = show n
renderValue _ (VFloat d)   = show d
renderValue _ (VString t)  = renderString t
renderValue lvl (VArray vs)    = renderArray lvl vs
renderValue lvl (VObject m)    = renderObject lvl m
renderValue lvl (VElement tag attrs children) =
  renderElement lvl tag attrs children

renderString :: Text -> String
renderString t
  | needsQuoting t = "\"" ++ escape (T.unpack t) ++ "\""
  | otherwise      = T.unpack t
  where
    escape []         = []
    escape ('"' : cs) = '\\' : '"' : escape cs
    escape ('\\': cs) = '\\' : '\\' : escape cs
    escape ('\n': cs) = '\\' : 'n'  : escape cs
    escape ('\r': cs) = '\\' : 'r'  : escape cs
    escape (c   : cs) = c : escape cs

needsQuoting :: Text -> Bool
needsQuoting t =
  T.null t
  || T.head t `elem` (":[]{},#&*!|>'\"%@`" :: String)
  || t `elem` ["true","false","null","yes","no","on","off",
                "True","False","Null","Yes","No","On","Off"]
  || T.any (`elem` ("\n\r:" :: String)) t

renderArray :: Int -> [UniversalValue] -> String
renderArray _ [] = "[]"
renderArray lvl vs =
  concatMap (\v -> "\n" ++ indent lvl ++ "- " ++ renderItem (lvl + 1) v) vs

renderItem :: Int -> UniversalValue -> String
renderItem lvl v@(VArray _)       = renderValue lvl v
renderItem lvl v@(VObject _)      = renderValue lvl v
renderItem lvl v@(VElement _ _ _) = renderValue lvl v
renderItem lvl v                  = renderValue lvl v

renderObject :: Int -> Map Text UniversalValue -> String
renderObject _ m | Map.null m = "{}"
renderObject lvl m =
  concatMap renderPair (Map.toAscList m)
  where
    renderPair (k, v) =
      "\n" ++ indent lvl ++ renderKey k ++ ": " ++ renderMappingValue (lvl + 1) v

renderKey :: Text -> String
renderKey k
  | needsQuoting k = "\"" ++ T.unpack k ++ "\""
  | otherwise      = T.unpack k

renderMappingValue :: Int -> UniversalValue -> String
renderMappingValue lvl v@(VArray vs)
  | null vs   = "[]"
  | otherwise = renderValue lvl v      
renderMappingValue lvl v@(VObject m)
  | Map.null m = "{}"
  | otherwise  = renderValue lvl v       
renderMappingValue lvl v@(VElement _ _ _) = renderValue lvl v
renderMappingValue lvl v                  = renderValue lvl v

renderElement :: Int -> Text -> Map Text Text -> [UniversalValue] -> String
renderElement lvl tag attrs children =
     "\n" ++ indent lvl ++ "_tag: "      ++ T.unpack tag
  ++ "\n" ++ indent lvl ++ "_attrs: "    ++ renderAttrs (lvl + 1) attrs
  ++ "\n" ++ indent lvl ++ "_children: " ++ renderChildren (lvl + 1) children

renderAttrs :: Int -> Map Text Text -> String
renderAttrs _ m | Map.null m = "{}"
renderAttrs lvl m =
  concatMap renderAttr (Map.toAscList m)
  where
    renderAttr (k, v) =
      "\n" ++ indent lvl ++ renderKey k ++ ": " ++ renderString v

renderChildren :: Int -> [UniversalValue] -> String
renderChildren _ [] = "[]"
renderChildren lvl vs =
  concatMap (\v -> "\n" ++ indent lvl ++ "- " ++ renderValue (lvl + 1) v) vs