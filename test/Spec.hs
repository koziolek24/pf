{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Test.Hspec
import qualified Data.Map.Strict as Map

import UniversalParser.AST
import UniversalParser.YamlParser (parseYAML)
import qualified JsonSpec
import qualified PrinterSpec

main :: IO ()
main = hspec $ do
  describe "Printers" PrinterSpec.spec
  describe "JSON Parser" JsonSpec.spec

  describe "YAML Parser" $ do
    describe "Scalars" $ do

      it "parses null" $
        parseYAML "~\n" `shouldBe` Right VNull

      it "parses true" $
        parseYAML "true\n" `shouldBe` Right (VBool True)

      it "parses false" $
        parseYAML "false\n" `shouldBe` Right (VBool False)

      it "parses integer" $
        parseYAML "42\n" `shouldBe` Right (VInt 42)

      it "parses negative integer" $
        parseYAML "-7\n" `shouldBe` Right (VInt (-7))

      it "parses float" $
        parseYAML "3.14\n" `shouldBe` Right (VFloat 3.14)

      it "parses string" $
        parseYAML "hello\n" `shouldBe` Right (VString "hello")

      it "parses quoted string that looks like int" $
        parseYAML "\"42\"\n" `shouldBe` Right (VString "42")

    describe "Collections" $ do

      it "parses a sequence" $
        parseYAML "- 1\n- 2\n- 3\n"
          `shouldBe` Right (VArray [VInt 1, VInt 2, VInt 3])

      it "parses a mapping" $
        parseYAML "name: Alice\nage: 30\n"
          `shouldBe` Right (VObject (Map.fromList
            [ ("name", VString "Alice")
            , ("age",  VInt 30)
            ]))

      it "parses nested structure" $
        parseYAML "person:\n  name: Bob\n  scores:\n    - 10\n    - 20\n"
          `shouldBe` Right (VObject (Map.fromList
            [ ("person", VObject (Map.fromList
                [ ("name",   VString "Bob")
                , ("scores", VArray [VInt 10, VInt 20])
                ]))
            ]))

    describe "Edge cases" $ do

      it "empty document is VNull" $
        parseYAML "" `shouldBe` Right VNull

      it "parses empty mapping" $
        parseYAML "{}\n" `shouldBe` Right (VObject Map.empty)

      it "parses empty sequence" $
        parseYAML "[]\n" `shouldBe` Right (VArray [])

      it "multi-document stream wrapped in VArray" $
        parseYAML "---\n1\n---\n2\n"
          `shouldBe` Right (VArray [VInt 1, VInt 2])
