{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module UniversalParser.YamlParser
  ( parseYAML
  , parseYAMLFile
  , ParseError
  ) where

import Control.Exception          (try, SomeException)
import Data.ByteString.Lazy       (ByteString)
import qualified Data.ByteString.Lazy as BS
import qualified Data.Map.Strict  as Map
import Data.Text                  (Text)
import qualified Data.Text        as T
import qualified Data.Text.Read   as TR

import qualified Data.YAML        as Y

import UniversalParser.AST

type ParseError = String

parseYAML :: ByteString -> Either ParseError UniversalValue
parseYAML bs =
  case Y.decodeNode bs of
    Left  err  -> Left $ "YAML parse error: " ++ show err
    Right docs -> case map convertDoc docs of
      []  -> Right VNull
      [v] -> Right v
      vs  -> Right (VArray vs)

parseYAMLFile :: FilePath -> IO (Either ParseError UniversalValue)
parseYAMLFile path = do
  result <- try (BS.readFile path) :: IO (Either SomeException ByteString)
  case result of
    Left  ex -> return . Left $ "IO error: " ++ show ex
    Right bs -> return $ parseYAML bs

convertDoc :: Y.Doc (Y.Node Y.Pos) -> UniversalValue
convertDoc (Y.Doc node) = convertNode node

convertNode :: Y.Node Y.Pos -> UniversalValue
convertNode node = case node of

  Y.Scalar _ scalar -> convertScalar scalar
  Y.Sequence _ _ items -> VArray (map convertNode items)
  Y.Mapping _ _ pairs ->
    VObject . Map.fromList $
      [ (nodeToText k, convertNode v) | (k, v) <- Map.toList pairs ]
  Y.Anchor _ _ inner -> convertNode inner

convertScalar :: Y.Scalar -> UniversalValue
convertScalar scalar = case scalar of
  Y.SNull        -> VNull
  Y.SBool b      -> VBool b
  Y.SFloat d     -> VFloat d
  Y.SInt  i      -> VInt i
  Y.SStr  t      -> VString t
  Y.SUnknown _ t -> resolveUnknown t

resolveUnknown :: Text -> UniversalValue
resolveUnknown t
  | isNull    t = VNull
  | isBoolT   t = VBool True
  | isBoolF   t = VBool False
  | otherwise   =
      case tryInt t of
        Just i  -> VInt i
        Nothing ->
          case tryFloat t of
            Just d  -> VFloat d
            Nothing -> VString t

isNull :: Text -> Bool
isNull t = t `elem` ["null", "Null", "NULL", "~", ""]

isBoolT :: Text -> Bool
isBoolT t = t `elem` ["true", "True", "TRUE"]

isBoolF :: Text -> Bool
isBoolF t = t `elem` ["false", "False", "FALSE"]

tryInt :: Text -> Maybe Integer
tryInt t =
  case T.stripPrefix "0x" t <> T.stripPrefix "0X" t of
    Just hex ->
      case TR.hexadecimal hex of
        Right (i, rest) | T.null rest -> Just i
        _                             -> Nothing
    Nothing ->
      case T.stripPrefix "0o" t <> T.stripPrefix "0O" t of
        Just oct ->
          case TR.decimal oct of
            Right (i, rest) | T.null rest -> Just i
            _                             -> Nothing
        Nothing ->
          case TR.signed TR.decimal t of
            Right (i, rest) | T.null rest -> Just i
            _                             -> Nothing

tryFloat :: Text -> Maybe Double
tryFloat t
  | t `elem` [".inf",  ".Inf",  ".INF",
               "+.inf", "+.Inf", "+.INF"] = Just (1/0)
  | t `elem` ["-.inf", "-.Inf", "-.INF"] = Just (negate 1/0)
  | t `elem` [".nan",  ".NaN",  ".NAN"]  = Just (0/0)
  | otherwise =
      case TR.signed TR.double t of
        Right (d, rest) | T.null rest -> Just d
        _                             -> Nothing

nodeToText :: Y.Node Y.Pos -> Text
nodeToText (Y.Scalar _ (Y.SStr  t)) = t
nodeToText (Y.Scalar _ (Y.SInt  i)) = T.pack (show i)
nodeToText (Y.Scalar _ (Y.SFloat d))= T.pack (show d)
nodeToText (Y.Scalar _ Y.SNull)     = "null"
nodeToText (Y.Scalar _ (Y.SBool b)) = if b then "true" else "false"
nodeToText other                    = T.pack (show other)
