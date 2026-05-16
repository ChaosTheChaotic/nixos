; Keywords
["use" "extern" "struct" "union" "enum" "if" "else" "while" "for" "switch" "case" "default" "defer" "ret" "break" "continue" "async" "inline" "static" "threadlocal" "mut"] @keyword

(use_statement "as" @keyword)

; Types
(primitive_type) @type.builtin
(type (identifier) @type)
(type "self" @type)
(member_access base: ("self") @variable.builtin)
(function_call caller: ("self") @variable.builtin)

; Struct, union, enum definitions
(struct_definition (identifier) @type)
(union_definition (identifier) @type)
(enum_definition (identifier) @type)

; Enum members
(enum_member (identifier) @constant)

; Function definitions and calls
(function_definition (identifier) @function)
(function_call caller: (identifier) @function)

; Member access without call
(member_access member: (identifier) @property)

; Method calls: obj.method()
(function_call caller: (member_access member: (identifier) @function))

; Use statement alias
(use_statement "as" (identifier) @namespace)

; Variables and parameters
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
["=" "+" "-" "*" "/" "%" "==" "!=" "<" ">" "<=" ">=" "&&" "||" "!" "&" "|" "^" "<<" ">>" 
 "++" "--" "+=" "-=" "*=" "/=" "%=" "^=" "<<=" ">>="] @operator
";" @punctuation.delimiter
"." @punctuation.delimiter

; Comments
(comment) @comment
