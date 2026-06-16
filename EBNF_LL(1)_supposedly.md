# EBNF for JSON, XML, YAML

## JSON

```EBNF
File         ::= Value
Dictionary   ::= "{" [ KeyValuePair { "," KeyValuePair } ] "}"
KeyValuePair ::= Str ":" Value
Value        ::= Dictionary | List | Literal 

Literal      ::= Str | Bool | Number | "null"
List         ::= "[" [ Value { "," Value } ] "]"

Str          ::= "\"" { Symbol } "\""
Bool         ::= "true" | "false"

Number       ::= [ "-" ] IntPart [ FracPart ] [ ExpPart ]
IntPart      ::= "0" | NonZeroNum { Num }
FracPart     ::= "." Num { Num }
ExpPart      ::= ( "e" | "E" ) [ "+" | "-" ] Num { Num }
```

```regex
Symbol <- char
NonZeroNum ::= r"[1-9]"
Num ::= r"[0-9]"
```

## XML

```EBNF
Document     ::= [ XmlDecl ] Element

XmlDecl      ::= "<?xml" { Attribute } "?>"

Element      ::= "<" Name { Attribute } ( "/>" | ">" Content "</" Name ">" )

Attribute    ::= Name "=" AttValue
AttValue     ::= '"' { CharMinusQuoteAmp } '"'
               | "'" { CharMinusAposAmp } "'"

Content      ::= { Element | Text | Reference | Comment }

Comment      ::= ""

Reference    ::= EntityRef | CharRef
EntityRef    ::= "&" Name ";"
CharRef      ::= "&#" DecNum ";" | "&#x" HexNum ";"

Name         ::= NameStart { NameChar }
```

```regex
NameStart          ::= r"[a-zA-Z_]"
NameChar           ::= r"[a-zA-Z0-9_\-\.]"
DecNum             ::= r"[0-9]+"
HexNum             ::= r"[0-9a-fA-F]+"
CharMinusQuoteAmp  ::= r"[^\"&]"
CharMinusAposAmp   ::= r"[^'&]"
CharMinusDash      ::= r"[^-]"
Text               ::= r"[^<&]+"
```

## YAML

```
YamlDocument ::= Value

Value        ::= BlockNode | FlowNode

BlockNode    ::= BlockMapping | BlockSequence | PlainScalar

BlockMapping ::= INDENT KeyValuePair { KeyValuePair } DEDENT
KeyValuePair ::= Key ":" ( Value | NEWLINE BlockNode ) NEWLINE

BlockSequence ::= INDENT { "-" ( Value | NEWLINE BlockNode ) NEWLINE } DEDENT

FlowNode     ::= FlowMapping | FlowSequence
FlowMapping  ::= "{" [ FlowPair { "," FlowPair } ] "}"
FlowSequence ::= "[" [ Value { "," Value } ] "]"
FlowPair     ::= Key ":" Value
```

```regex
(* Terminals *)
Key          ::= PlainScalar
PlainScalar  ::= ScalarChar { ScalarChar }
```