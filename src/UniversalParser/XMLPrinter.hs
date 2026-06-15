{-# LANGUAGE OverloadedStrings #-}

module UniversalParser.XMLPrinter where

import UniversalParser.AST
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T

toXml :: UniversalValue -> String
toXml v = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" ++ renderValue 0 v

indent :: Int -> String
indent n = replicate (n * 2) ' '

renderValue :: Int -> UniversalValue -> String
renderValue lvl (VElement tag attrs children) = renderElement lvl tag attrs children
renderValue lvl v                             = renderElement lvl "value" Map.empty [v]

renderElement :: Int -> Text -> Map Text Text -> [UniversalValue] -> String
renderElement lvl tag attrs children =
  indent lvl ++ "<" ++ T.unpack tag ++ renderAttrs attrs ++ close
  where
    close
      | null children = "/>"
      | otherwise     =
          ">\n"
          ++ concatMap (\c -> renderChild (lvl + 1) c ++ "\n") children
          ++ indent lvl ++ "</" ++ T.unpack tag ++ ">"

renderAttrs :: Map Text Text -> String
renderAttrs m
  | Map.null m = ""
  | otherwise  = " " ++ unwords (map renderAttr (Map.toAscList m))
  where
    renderAttr (k, v) = T.unpack k ++ "=\"" ++ escapeAttr (T.unpack v) ++ "\""

renderChild :: Int -> UniversalValue -> String
renderChild lvl (VElement tag attrs children) = renderElement lvl tag attrs children
renderChild lvl (VString t)                   = indent lvl ++ escapeText (T.unpack t)
renderChild lvl VNull                         = indent lvl ++ "<null/>"
renderChild lvl (VBool True)                  = indent lvl ++ "<bool>true</bool>"
renderChild lvl (VBool False)                 = indent lvl ++ "<bool>false</bool>"
renderChild lvl (VInt n)                      = indent lvl ++ "<number>" ++ show n ++ "</number>"
renderChild lvl (VFloat d)                    = indent lvl ++ "<number>" ++ show d ++ "</number>"
renderChild lvl (VArray vs)                   = renderArrayChild lvl vs
renderChild lvl (VObject m)                   = renderObjectChild lvl m

renderArrayChild :: Int -> [UniversalValue] -> String
renderArrayChild lvl vs =
  indent lvl ++ "<array>\n"
  ++ concatMap (\v -> renderChild (lvl + 1) v ++ "\n") vs
  ++ indent lvl ++ "</array>"

renderObjectChild :: Int -> Map Text UniversalValue -> String
renderObjectChild lvl m =
  indent lvl ++ "<object>\n"
  ++ concatMap renderPair (Map.toAscList m)
  ++ indent lvl ++ "</object>"
  where
    renderPair (k, v) =
      indent (lvl + 1) ++ "<" ++ T.unpack k ++ ">\n"
      ++ renderChild (lvl + 2) v ++ "\n"
      ++ indent (lvl + 1) ++ "</" ++ T.unpack k ++ ">\n"

escapeText :: String -> String
escapeText [] = []
escapeText ('&'  : cs) = "&amp;"  ++ escapeText cs
escapeText ('<'  : cs) = "&lt;"   ++ escapeText cs
escapeText ('>'  : cs) = "&gt;"   ++ escapeText cs
escapeText (c    : cs) = c : escapeText cs

escapeAttr :: String -> String
escapeAttr [] = []
escapeAttr ('&'  : cs) = "&amp;"  ++ escapeAttr cs
escapeAttr ('<'  : cs) = "&lt;"   ++ escapeAttr cs
escapeAttr ('"'  : cs) = "&quot;" ++ escapeAttr cs
escapeAttr (c    : cs) = c : escapeAttr cs