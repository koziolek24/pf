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

renderValue :: Int -> UniversalValue -> String
renderValue lvl (VElement tag attrs children) = renderElement lvl tag attrs children
renderValue lvl (VObject m)                   = renderObjectChild lvl m
renderValue lvl (VArray vs)                   = renderArrayChild lvl vs
renderValue lvl v                             = renderScalarTag lvl v

renderScalarTag :: Int -> UniversalValue -> String
renderScalarTag lvl VNull       = indent lvl ++ "<null/>"
renderScalarTag lvl (VBool b)   = indent lvl ++ "<bool>" ++ (if b then "true" else "false") ++ "</bool>"
renderScalarTag lvl (VInt n)    = indent lvl ++ "<number>" ++ show n ++ "</number>"
renderScalarTag lvl (VFloat d)  = indent lvl ++ "<number>" ++ show d ++ "</number>"
renderScalarTag lvl (VString t) = indent lvl ++ escapeText (T.unpack t)
renderScalarTag lvl (VArray vs)  = renderArrayChild lvl vs
renderScalarTag lvl (VObject m)  = renderObjectChild lvl m
renderScalarTag lvl (VElement tag attrs children) = renderElement lvl tag attrs children

renderChild :: Int -> UniversalValue -> String
renderChild = renderScalarTag

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
      (case v of
        VString t ->
          indent (lvl + 1) ++ "<" ++ T.unpack k ++ ">" ++ escapeText (T.unpack t) ++ "</" ++ T.unpack k ++ ">"
        VNull ->
          indent (lvl + 1) ++ "<" ++ T.unpack k ++ "/>"
        _ ->
          indent (lvl + 1) ++ "<" ++ T.unpack k ++ ">\n"
          ++ renderChild (lvl + 2) v ++ "\n"
          ++ indent (lvl + 1) ++ "</" ++ T.unpack k ++ ">") ++ "\n"

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