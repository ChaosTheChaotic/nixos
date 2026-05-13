; Keywords
["use" "extern" "struct" "union" "enum" "if" "else" "while" "for" "switch" "case" "default" "defer" "ret" "break" "continue" "async" "inline" "static" "threadlocal" "mut"] @keyword

; Types
(primitive_type) @type.builtin
(type (identifier) @type)
(type "self" @type)
(member_access base: ("self") @variable.builtin)
(function_call caller: ("self") @variable.builtin)

; Functions and Variables
(function_definition (identifier) @function)
(variable_declaration (identifier) @variable)
(parameter (identifier) @variable.parameter)

; Literals
(number_literal) @number
(string_literal) @string
(char_literal) @string.special
(boolean_literal) @boolean
(null_literal) @constant.builtin

; Punctuation/Operators
["(" ")" "[" "]" "{" "}"] @punctuation.bracket
["=" "+" "-" "*" "/" "%" "==" "!=" "<" ">" "<=" ">=" "&&" "||" "!" "&" "|" "^" "<<" ">>"] @operator
";" @punctuation.delimiter
"." @punctuation.delimiter

(comment) @comment
