{-# LANGUAGE OverloadedStrings #-}

module Main where

import System.Environment (getArgs)
import System.Exit        (exitFailure)

import UniversalParser.YamlParser  (parseYAMLFile)
import UniversalParser.JsonParser  (parseJSONFile)
import UniversalParser.XMLParser   (parseXMLFile)
import UniversalParser.YamlPrinter (toYaml)
import UniversalParser.JsonPrinter (toJson)
import UniversalParser.XMLPrinter  (toXml)
import UniversalParser.AST


main :: IO ()
main = do
  args <- getArgs
  case args of
    [inPath, outFmt] -> do
      result <- parseByExt inPath
      case result of
        Left  err -> putStrLn ("Error: " ++ err) >> exitFailure
        Right ast -> putStrLn (renderByFmt outFmt ast)
    [inPath] -> do
      result <- parseByExt inPath
      case result of
        Left  err -> putStrLn ("Error: " ++ err) >> exitFailure
        Right ast -> putStrLn (toYaml ast)
    _ -> do
      putStrLn "Usage: universal-parser <file> [yaml|json|xml]"
      exitFailure

parseByExt :: FilePath -> IO (Either String UniversalValue)
parseByExt path
  | ".yaml" `isSuffixOf` path || ".yml" `isSuffixOf` path = parseYAMLFile path
  | ".json" `isSuffixOf` path                              = parseJSONFile path
  | ".xml"  `isSuffixOf` path                              = parseXMLFile  path
  | otherwise = return . Left $ "unknown extension: " ++ path

renderByFmt :: String -> UniversalValue -> String
renderByFmt "yaml" = toYaml
renderByFmt "json" = toJson
renderByFmt "xml"  = toXml
renderByFmt fmt    = \_ -> "Error: unknown format: " ++ fmt

isSuffixOf :: String -> String -> Bool
isSuffixOf suffix str = drop (length str - length suffix) str == suffix