%option noyywrap
%option nounput
%option noinput
%x COMMENT

%{

#include <cstdlib>
#include <string>
enum OP
{
    EQ_OP,NEQ_OP,LT_OP,GT_OP,LEQ_OP,GEQ_OP,PLUS_OP,MINUS_OP,MUL_OP,DIV_OP,MOD_OP,AND_OP,OR_OP,NOT_OP,ASSIGN_OP
};
struct Node {
    int value;
    bool is_const;
    int offset;
    Node()=default;
    Node(int _value, bool _is_const) 
    {
        is_const=_is_const;
        if(is_const)
            value=_value;
        else
            offset=_value;
    }
};
// 因为 Flex 会用到 Bison 中关于 token 的定义
// 所以需要 include Bison 生成的头文件
#include "sysy.tab.hpp"

using namespace std;
int in_comment = 0; // 是否在注释状态下
%}

/* 空白符和注释 */
WhiteSpace    [ \t\n\r]*
LineComment   "//".*

/* 标识符 */
Identifier    [a-zA-Z_][a-zA-Z0-9_]*

/* 整数字面量 */
Decimal       [1-9][0-9]*
Octal         0[0-7]*
Hexadecimal   0[xX][0-9a-fA-F]+

%%

{WhiteSpace}    { /* 忽略, 不做任何操作 */ }
{LineComment}   { /* 忽略, 不做任何操作 */ }

"const"         { return CONST; }

"int"           { return INT; }
"return"        { return RETURN; }
"if"            { return IF; }
"else"          { return ELSE; }
"while"         { return WHILE; }
"break"         { return BREAK; }
"continue"      { return CONTINUE; }
"void"          { return VOID; }
"scanf"         { return SCANF; }
"printf"        { return PRINTF; }

{Identifier}    { yylval.str_val = new string(yytext); return IDENT; }

{Decimal}       { yylval.int_val = strtol(yytext, nullptr, 0); return INT_CONST; }
{Octal}         { yylval.int_val = strtol(yytext, nullptr, 0); return INT_CONST; }
{Hexadecimal}   { yylval.int_val = strtol(yytext, nullptr, 0); return INT_CONST; }

">="            { return GEQ; }
"<="            { return LEQ; }
"=="            { return EQ; }
"!="            { return NEQ; }
"&&"            { return AND; }
"||"            { return OR; }


"/*"      { BEGIN(COMMENT); }
<COMMENT>{
  "*/"     { BEGIN(INITIAL); }
  .|\n     { /* 忽略注释中的字符 */ }
}
.               { return yytext[0]; }

%%
