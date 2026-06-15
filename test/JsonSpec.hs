{-# LANGUAGE OverloadedStrings #-}

module JsonSpec (spec) where

import Test.Hspec
import qualified Data.Map.Strict as Map

import UniversalParser.AST
import UniversalParser.JsonParser (parseJSON)

spec :: Spec
spec = do

  describe "Scalars" $ do

    it "parses null" $
      parseJSON "null" `shouldBe` Right VNull

    it "parses true" $
      parseJSON "true" `shouldBe` Right (VBool True)

    it "parses false" $
      parseJSON "false" `shouldBe` Right (VBool False)

    it "parses integer" $
      parseJSON "42" `shouldBe` Right (VInt 42)

    it "parses negative integer" $
      parseJSON "-7" `shouldBe` Right (VInt (-7))

    it "parses float" $
      parseJSON "3.14" `shouldBe` Right (VFloat 3.14)

    it "parses string" $
      parseJSON "\"hello\"" `shouldBe` Right (VString "hello")

    it "parses quoted string that looks like int" $
      parseJSON "\"42\"" `shouldBe` Right (VString "42")

  describe "Collections" $ do

    it "parses a sequence" $
      parseJSON "[1, 2, 3]"
        `shouldBe` Right (VArray [VInt 1, VInt 2, VInt 3])

    it "parses a mapping" $
      parseJSON "{\"name\": \"Alice\", \"age\": 30}"
        `shouldBe` Right (VObject (Map.fromList
          [ ("name", VString "Alice")
          , ("age",  VInt 30)
          ]))

    it "parses nested structure" $
      parseJSON "{\"person\": {\"name\": \"Bob\", \"scores\": [10, 20]}}"
        `shouldBe` Right (VObject (Map.fromList
          [ ("person", VObject (Map.fromList
              [ ("name",   VString "Bob")
              , ("scores", VArray [VInt 10, VInt 20])
              ]))
          ]))

  describe "Edge cases" $ do

    it "parses empty mapping" $
      parseJSON "{}" `shouldBe` Right (VObject Map.empty)

    it "parses empty sequence" $
      parseJSON "[]" `shouldBe` Right (VArray [])
