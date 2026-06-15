{-# LANGUAGE OverloadedStrings #-}

module UniversalParser.XMLParser
  ( parseXML
  , parseXMLFile
  , ParseError
  ) where

import Control.Exception (SomeException, try)
import Data.Char (isAlpha, isAlphaNum, isSpace, digitToInt)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.ByteString as BS
import qualified Data.Text.Encoding as TE
import UniversalParser.AST (UniversalValue(..))

type ParseError = String
type Input = String

data Parser a = Parser { runParser :: Input -> Either ParseError (a, Input) }

instance Functor Parser where
  fmap f (Parser p) = Parser $ \inp -> do
    (a, rest) <- p inp
    return (f a, rest)

instance Applicative Parser where
  pure a = Parser $ \inp -> Right (a, inp)
  Parser pf <*> Parser pa = Parser $ \inp -> do
    (f, rest1) <- pf inp
    (a, rest2) <- pa rest1
    return (f a, rest2)

instance Monad Parser where
  return = pure
  Parser pa >>= f = Parser $ \inp -> do
    (a, rest) <- pa inp
    runParser (f a) rest

failP :: ParseError -> Parser a
failP err = Parser $ \_ -> Left err

satisfy :: (Char -> Bool) -> Parser Char
satisfy p = Parser $ \inp -> case inp of
  []     -> Left "unexpected end of input"
  (c:cs) -> if p c then Right (c, cs) else Left $ "unexpected char: " ++ show c

char :: Char -> Parser Char
char c = satisfy (== c)

string :: String -> Parser String
string [] = return []
string (c:cs) = do
  _ <- char c
  _ <- string cs
  return (c:cs)

many :: Parser a -> Parser [a]
many p = Parser $ \inp ->
  case runParser p inp of
    Left _        -> Right ([], inp)
    Right (a, r)  -> case runParser (many p) r of
      Left _         -> Right ([a], r)
      Right (as, r') -> Right (a:as, r')

many1 :: Parser a -> Parser [a]
many1 p = do
  a  <- p
  as <- many p
  return (a:as)

skipSpaces :: Parser ()
skipSpaces = Parser $ \inp -> Right ((), dropWhile isSpace inp)

parseXML :: BS.ByteString -> Either ParseError UniversalValue
parseXML bs =
  case TE.decodeUtf8' bs of
    Left err -> Left $ "UTF-8 decode error: " ++ show err
    Right t  ->
      case runParser document (T.unpack t) of
        Left err      -> Left $ "XML parse error: " ++ err
        Right (v, r)  ->
          let rest = dropWhile isSpace r
          in if null rest
             then Right v
             else Left $ "unexpected trailing input: " ++ take 20 rest

parseXMLFile :: FilePath -> IO (Either ParseError UniversalValue)
parseXMLFile path = do
  result <- try (BS.readFile path) :: IO (Either SomeException BS.ByteString)
  case result of
    Left ex -> return . Left $ "IO error: " ++ show ex
    Right bs -> return $ parseXML bs

document :: Parser UniversalValue
document = do
  skipSpaces
  _ <- many (xmlDecl >> skipSpaces)
  _ <- many (comment >> skipSpaces)
  skipSpaces
  element

xmlDecl :: Parser ()
xmlDecl = do
  _ <- string "<?"
  _ <- many (satisfy (\c -> c /= '?'))
  _ <- string "?>"
  return ()

comment :: Parser ()
comment = do
  _ <- string "<!--"
  skipCommentBody
  return ()

skipCommentBody :: Parser ()
skipCommentBody = Parser $ \inp ->
  case breakOn "-->" inp of
    Nothing       -> Left "unclosed comment"
    Just (_, r)   -> Right ((), drop 3 r)

breakOn :: String -> String -> Maybe (String, String)
breakOn _   [] = Nothing
breakOn sub s@(c:cs)
  | take (length sub) s == sub = Just ([], s)
  | otherwise                  = fmap (\(pre, post) -> (c:pre, post)) (breakOn sub cs)

element :: Parser UniversalValue
element = do
  _       <- char '<'
  tag     <- name
  attrs   <- many (skipSpaces >> attribute)
  skipSpaces
  selfClose <- tryP (string "/>")
  case selfClose of
    Just _  -> return $ VElement (T.pack tag) (Map.fromList attrs) []
    Nothing -> do
      _ <- char '>'
      children <- content
      _ <- string "</"
      closingTag <- name
      if closingTag /= tag
        then failP $ "mismatched tags: <" ++ tag ++ "> closed by </" ++ closingTag ++ ">"
        else do
          skipSpaces
          _ <- char '>'
          return $ VElement (T.pack tag) (Map.fromList attrs) (filterEmpty children)

filterEmpty :: [UniversalValue] -> [UniversalValue]
filterEmpty = filter $ \v -> case v of
  VString t -> not (T.null (T.strip t))
  _         -> True

tryP :: Parser a -> Parser (Maybe a)
tryP p = Parser $ \inp ->
  case runParser p inp of
    Left _       -> Right (Nothing, inp)
    Right (a, r) -> Right (Just a, r)

attribute :: Parser (Text, Text)
attribute = do
  k <- name
  skipSpaces
  _ <- char '='
  skipSpaces
  v <- attValue
  return (T.pack k, T.pack v)

attValue :: Parser String
attValue = doubleQuoted <|> singleQuoted
  where
    doubleQuoted = do
      _ <- char '"'
      cs <- many (attChar '"')
      _ <- char '"'
      return cs
    singleQuoted = do
      _ <- char '\''
      cs <- many (attChar '\'')
      _ <- char '\''
      return cs
    attChar q = reference <|> satisfy (\c -> c /= q && c /= '&')

(<|>) :: Parser a -> Parser a -> Parser a
Parser p1 <|> Parser p2 = Parser $ \inp ->
  case p1 inp of
    Right r -> Right r
    Left _  -> p2 inp

content :: Parser [UniversalValue]
content = many contentItem

contentItem :: Parser UniversalValue
contentItem =
      fmap (VString . T.pack . concat) (many1 textChunk)
  <|> element
  <|> (comment >> return VNull)

textChunk :: Parser String
textChunk =
      fmap (:[]) reference
  <|> fmap (:[]) (satisfy (\c -> c /= '<' && c /= '&'))

reference :: Parser Char
reference = do
  _ <- char '&'
  r <- entityRef <|> charRef
  _ <- char ';'
  return r

entityRef :: Parser Char
entityRef = do
  n <- name
  case n of
    "amp"  -> return '&'
    "lt"   -> return '<'
    "gt"   -> return '>'
    "quot" -> return '"'
    "apos" -> return '\''
    _      -> failP $ "unknown entity: &" ++ n ++ ";"

charRef :: Parser Char
charRef = hexRef <|> decRef
  where
    hexRef = do
      _ <- string "#x"
      ds <- many1 (satisfy isHexDigit)
      return . toEnum $ foldl (\acc d -> acc * 16 + digitToInt d) 0 ds
    decRef = do
      _ <- char '#'
      ds <- many1 (satisfy isDecDigit)
      return . toEnum $ foldl (\acc d -> acc * 10 + digitToInt d) 0 ds
    isHexDigit c = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
    isDecDigit c = c >= '0' && c <= '9'

name :: Parser String
name = do
  c  <- satisfy isNameStart
  cs <- many (satisfy isNameChar)
  return (c:cs)

isNameStart :: Char -> Bool
isNameStart c = isAlpha c || c == '_'

isNameChar :: Char -> Bool
isNameChar c = isAlphaNum c || c == '_' || c == '-' || c == '.'