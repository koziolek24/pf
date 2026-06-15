{-# LANGUAGE OverloadedStrings #-}

module Main where

import System.Environment (getArgs)
import System.Exit        (exitFailure)

import UniversalParser.YamlParser (parseYAMLFile)
import UniversalParser.YamlPrinter (toYaml)
import UniversalParser.AST


import Data.List (intercalate)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T

-- main :: IO ()
-- main = do
--   args <- getArgs
--   case args of
--     [path] -> do
--       result <- parseYAMLFile path
--       case result of
--         Left  err -> putStrLn ("Error: " ++ err) >> exitFailure
--         Right ast -> putStrLn (prettyValue ast)
--     _ -> putStrLn "Usage: yaml-parser <file.yaml>" >> exitFailure


main :: IO ()
main = do
  let example =
        VObject $ Map.fromList
          [ ("name",    VString "Alice")
          , ("age",     VInt 30)
          , ("active",  VBool True)
          , ("score",   VFloat 9.5)
          , ("notes",   VNull)
          , ("tags",    VArray [VString "admin", VString "user"])
          , ("address", VObject $ Map.fromList
                [ ("city",    VString "Warsaw")
                , ("country", VString "Poland")
                ])
          , ("page",    VElement "div"
                          (Map.fromList [("class", "container"), ("id", "main")])
                          [ VElement "p" Map.empty [VString "Hello, world!"]
                          , VString "plain text node"
                          ])
          ]
  putStr (toYaml example)
