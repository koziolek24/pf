# Universal Parser — dokumentacja

Konwerter między formatami JSON, YAML i XML, oparty na jednym wspólnym
drzewie danych (`UniversalValue`). Parser dowolnego formatu produkuje to
samo AST, a printer dowolnego formatu konsumuje to samo AST.

## Architektura

```
   plik wejściowy            UniversalValue              plik wyjściowy
  (yaml/json/xml)  --parser-->   (AST)    --printer-->   (yaml/json/xml)
```

### AST — `UniversalParser.AST`

```haskell
data UniversalValue
  = VNull
  | VBool Bool
  | VInt Integer
  | VFloat Double
  | VString Text
  | VArray [UniversalValue]
  | VObject (Map Text UniversalValue)
  | VElement Text (Map Text Text) [UniversalValue]
  deriving (Show, Eq)
```

`VNull` … `VObject` pokrywają wspólny rdzeń JSON/YAML. `VElement tag attrs
children` jest natywny dla XML (tag, atrybuty, dzieci) i nie ma
odpowiednika w JSON/YAML — przy konwersji XML → JSON/YAML jest spłaszczany
do `VObject`/`VString`.

## Parsery

### JsonParser

Oparty na bibliotece `aeson`. `Aeson.eitherDecode` wykonuje całe
parsowanie tekstu; kod własny ogranicza się do konwersji drzewa
`Aeson.Value` na `UniversalValue` (`convertValue`). Liczby (`Scientific`)
są rozdzielane na `VInt`/`VFloat` przez `floatingOrInteger`.

```haskell
parseJSON     :: ByteString -> Either ParseError UniversalValue
parseJSONFile :: FilePath   -> IO (Either ParseError UniversalValue)
```

### YamlParser

Oparty na bibliotece `HsYAML` (`Data.YAML`). `Y.decodeNode` parsuje
strukturę dokumentu (wcięcia, anchors, multi-doc). Część dodatkowa to
`resolveUnknown` — YAML 1.1 ma niejednoznaczne skalary bez tagu
(`SUnknown`), więc kod własny rozpoznaje ręcznie: null (`null`, `~`, ``),
bool (`true`/`false` w różnych wariantach wielkości liter), int (dziesiętny,
hex `0x`, oktalny `0o`), float (w tym `.inf`, `-.inf`, `.nan`).

```haskell
parseYAML     :: ByteString -> Either ParseError UniversalValue
parseYAMLFile :: FilePath   -> IO (Either ParseError UniversalValue)
```

### XmlParser

Pisany ręcznie — własny parser kombinatorowy (`Parser` jako `Functor` /
`Applicative` / `Monad` nad `Either ParseError`), zgodny z gramatyką EBNF
projektu. Obsługuje: deklarację `<?xml ... ?>`, komentarze `<!-- -->`,
elementy z atrybutami i self-closing tagami, mixed content (tekst +
elementy przeplatane), entity references (`&amp; &lt; &gt; &quot; &apos;`)
i character references (`&#65;`, `&#x41;`). Walidacja zgodności tagów
otwierającego/zamykającego. Czysto whitespace'owe text node'y między
tagami są odfiltrowywane.

```haskell
parseXML     :: ByteString -> Either ParseError UniversalValue
parseXMLFile :: FilePath   -> IO (Either ParseError UniversalValue)
```

## Printery

### JsonPrinter

Renderer rekurencyjny, 2-spacjowe wcięcia. Stringi escapowane
zgodnie z RFC 8259 (`"`, `\`, `\n`, `\r`, `\t`, znaki kontrolne jako
`\uXXXX`). Klucze obiektów zawsze w cudzysłowach, posortowane alfabetycznie
(`Map.toAscList`). Puste tablice/obiekty renderowane inline jako `[]`/`{}`.

```haskell
toJson :: UniversalValue -> String
```

### YamlPrinter

Renderer, block style YAML (myślniki dla list, `key: value` dla
map), 2-spacjowe wcięcia. Stringi cytowane tylko gdy potrzebne
(`needsQuoting`: zaczynają się znakiem specjalnym, są słowem kluczowym
typu `true`/`null`, zawierają `:`/newline, lub są puste) — w przeciwnym
razie drukowane bez cudzysłowów. Dokument otwierany przez `---`.

```haskell
toYaml :: UniversalValue -> String
```

### XmlPrinter

Własny renderer. `VElement` renderowany natywnie jako tag XML z
atrybutami. `VObject`/`VArray`/skalary (czyli dane bez naturalnej struktury
XML, np. sparsowany JSON) są kodowane przez wprowadzone tagi pomocnicze:
`<object>`, `<array>`, `<bool>`, `<number>`, `<null/>` — string i pozostałe
skalary wewnątrz tych struktur są inline'owane bez zbędnych wcięć. Znaki
specjalne escapowane osobno dla treści (`&amp; &lt; &gt;`) i atrybutów
(dodatkowo `&quot;`).

```haskell
toXml :: UniversalValue -> String
```

## Ograniczenia i decyzje projektowe

- **`VElement` nie ma odpowiednika w JSON/YAML.** Round-trip
  XML → JSON/YAML → XML nie jest idealny i daje straty dla struktury tagów.
- **Pusty `VObject`/`[]` vs `VNull` w XML.** XML nie rozróżnia pustego
  elementu od braku wartości — `empty_map: {}` i `notes: null` mogą się
  zlać w reprezentacji `<tag/>`.
- **Kolejność kluczy nie jest zachowywana.** `Map Text a` sortuje
  alfabetycznie; insertion order z oryginalnego pliku jest tracony przy
  każdej konwersji.
- **Namespace'y XML są ignorowane** — `XmlParser` nie rozróżnia
  `<ns:tag>` od `<tag>`, traktuje cały prefiks jako część nazwy tagu.

## Użycie

```bash
cabal build
cabal run yaml-parser -- example.yaml json   # yaml -> json
cabal run yaml-parser -- example.json xml    # json -> xml
cabal run yaml-parser -- example.xml yaml    # xml  -> yaml
```
