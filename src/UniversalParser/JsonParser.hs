{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module UniversalParser.JsonParser
  ( parseJSON,
    parseJSONFile,
    ParseError,
  )
where

import Control.Exception (SomeException, try)
import Data.Aeson (Value (..))
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KM
import Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString.Lazy as BS
import qualified Data.Map.Strict as Map
import Data.Scientific (floatingOrInteger)
import qualified Data.Vector as V
import UniversalParser.AST (UniversalValue (VArray, VBool, VFloat, VInt, VNull, VObject, VString))

type ParseError = String

parseJSON :: ByteString -> Either ParseError UniversalValue
parseJSON bs =
  case Aeson.eitherDecode bs of
    Left err -> Left $ "JSON parse error: " ++ err
    Right val -> Right (convertValue val)

parseJSONFile :: FilePath -> IO (Either ParseError UniversalValue)
parseJSONFile path = do
  result <- try (BS.readFile path) :: IO (Either SomeException ByteString)
  case result of
    Left ex -> return . Left $ "IO error: " ++ show ex
    Right bs -> return $ parseJSON bs

convertValue :: Aeson.Value -> UniversalValue
convertValue value = case value of
  Null -> VNull
  Bool b -> VBool b
  String s -> VString s
  Number n -> case floatingOrInteger n of
    Left f -> VFloat f
    Right i -> VInt i
  Array xs -> VArray (map convertValue (V.toList xs))
  Object obj ->
    VObject . Map.fromList $
      [(Key.toText k, convertValue v) | (k, v) <- KM.toList obj]