Retiens que
Le langage GAMMA est défini avec la grammaire BNF suivante

PROGRAMME        ::= [ INSTRUCTION_LIST ]
INSTRUCTION_LIST ::= INSTRUCTION | INSTRUCTION_LIST INSTRUCTION
INSTRUCTION      ::= ASSIGNATION 
ASSIGNATION      ::= VARNAME ASSIGN_OPERATEUR EXPRESSION
ASSIGN_OPERATEUR ::= "+=" | "?=" | "=" | "!="
EXPRESSION       ::= ( ITEM | EXPRESSION ITEM )*
ITEM             ::= VALUE | VARIABLE
VARIABLE         ::= "{{" VARIABLE_NAME "}}"
VARIABLE_NAME    ::= [A-Z]+
VALUE            ::= [a-zA-Z0-9]*

Le langage GAMMA doit suivre N règles de la maniere suivante concernant la règle de la grammaire décrite par ASSIGNATION ::= VARNAME ASSIGN_OPERATEUR EXPRESSION

la premiere regle pour ASSIGNATION est :
le caractere opérateur "=" membre de ASSIGN_OPERATEUR affecte la valeur de EXPRESSION à la VARIABLE

la deuxieme regle pour ASSIGNATION est :
le caractere opérateur "?="  membre de ASSIGN_OPERATEUR signifie que VARIABLE doit être évalué tardivement ainsi que dans chaque INSTRUCTION suivante où VARIABLE est utilisée . Quand la VARIABLE sera assignée pour la premiere fois avec une valeur alors chaque INSTRUCTION contenant la VARIABLE sera réévaluée. 
le caractere opérateur "?=" assigne à la VARIABLE la valeur de EXPRESSION  si la VARIABLE a déja été assignée avec le caractere opérateur "=" dans une INSTRUCTION précédente ou si la VARIABLE a était réévaluée et que la valeur de la VARIABLE est nulle ou vide.

la troisieme regle pour ASSIGNATION est :
le caractere opérateur "+=" membre de ASSIGN_OPERATEUR concatene la valeur actuelle la VARIABLE VARNAME avec la valeur de EXPRESSION









Retiens que
Le langage ZETA est défini avec la grammaire BNF suivante

PROGRAMME        ::= [ INSTRUCTION_LIST ]
INSTRUCTION_LIST ::= INSTRUCTION | INSTRUCTION_LIST INSTRUCTION
INSTRUCTION      ::= ASSIGNATION 
ASSIGNATION      ::= VARNAME ASSIGN_OPERATEUR EXPRESSION
ASSIGN_OPERATEUR ::= "+=" | "?=" | "=" | "!="
EXPRESSION       ::= ( ITEM | EXPRESSION ITEM )*
ITEM             ::= VALUE | VARIABLE
VARIABLE         ::= "{{" VARIABLE_NAME "}}"
VARIABLE_NAME    ::= [A-Z]+
VALUE            ::= [a-zA-Z0-9]*


Le langage ZETA doit suivre les 3 règles suivantes concernant la règle de la grammaire décrite par ASSIGNATION ::= VARNAME ASSIGN_OPERATEUR EXPRESSION

la premiere règle est :
le caractere opérateur "=" membre de ASSIGN_OPERATEUR affecte la valeur de EXPRESSION à la VARIABLE

la deuxième règle est :
le caractere opérateur "+=" membre de ASSIGN_OPERATEUR concatene la valeur actuelle la VARIABLE et la valeur de EXPRESSION

la troisième règle est :
le caractere opérateur "?=" membre de ASSIGN_OPERATEUR assigne à la VARIABLE la valeur de EXPRESSION si et seulement si la valeur actuelle de VARIABLE est nulle ou vide



oublie toutes les variables evalue le programme écrit en ZETA suivant
A=2
B=3
D?={{B}} {{A}}
J={{D}}
D+=8
D={{A}}
D+=9
et affiche la valeur de chacune des variables