{-# LANGUAGE OverloadedStrings #-}

module PrinterSpec (spec) where

import Test.Hspec
import qualified Data.Map.Strict as Map

import UniversalParser.AST
import UniversalParser.JsonPrinter (toJson)
import UniversalParser.YamlPrinter (toYaml)

spec :: Spec
spec = do

  describe "JSON Printer" $ do
    it "prints null" $
      toJson VNull `shouldBe` "null"

    it "prints boolean" $ do
      toJson (VBool True) `shouldBe` "true"
      toJson (VBool False) `shouldBe` "false"

    it "prints integer" $
      toJson (VInt 42) `shouldBe` "42"

    it "prints float" $
      toJson (VFloat 3.14) `shouldBe` "3.14"

    it "prints string" $
      toJson (VString "hello") `shouldBe` "\"hello\""

    it "prints simple array" $
      toJson (VArray [VInt 1, VInt 2]) `shouldBe` "[\n  1,\n  2\n]"

    it "prints simple object" $
      toJson (VObject (Map.fromList [("key", VInt 42)])) `shouldBe` "{\n  \"key\": 42\n}"

  describe "YAML Printer" $ do
    it "prints null" $
      toYaml VNull `shouldBe` "---\nnull\n"

    it "prints boolean" $ do
      toYaml (VBool True) `shouldBe` "---\ntrue\n"
      toYaml (VBool False) `shouldBe` "---\nfalse\n"

    it "prints integer" $
      toYaml (VInt 42) `shouldBe` "---\n42\n"

    it "prints float" $
      toYaml (VFloat 3.14) `shouldBe` "---\n3.14\n"

    it "prints string" $
      toYaml (VString "hello") `shouldBe` "---\nhello\n"

    it "prints simple array" $
      toYaml (VArray [VInt 1, VInt 2]) `shouldBe` "---\n\n- 1\n- 2\n"

    it "prints simple object" $
      toYaml (VObject (Map.fromList [("key", VInt 42)])) `shouldBe` "---\n\nkey: 42\n"
