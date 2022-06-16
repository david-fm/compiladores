%{
#include "listaCodigo.h"
#include "listaSimbolos.h"
#include "math.h"
#include "miniC.tab.h"

int lineaComienzo=0;
int idComprobacion();
int enteroComprobacion(double numero);
%}
digito              [0-9]
letra               [a-zA-Z]
entero              {digito}+
%option yylineno
%x COMMENT
%x CAD
%%
"/*"                                        {lineaComienzo=yylineno;BEGIN COMMENT;}
<COMMENT>"*"+"/"                            BEGIN 0;
<COMMENT><<EOF>>                            {printf("Error Lexico: Comentario sin cerrar comenzando en la linea %d\n", lineaComienzo);return 0;}
<COMMENT>[^*]*                               ;
<COMMENT>"*"+[^/*]*                          ;

["]                                         {lineaComienzo=yylineno;BEGIN (CAD);}
<CAD>["]                                 {BEGIN 0; return STRING;}
<CAD><<EOF>>                             {printf("Error Lexico: Error Cadena sin cerrar en la linea %d\n",lineaComienzo);return 0;}
<CAD>([^"\\]|\\.)*                       {yylval.lexema = strdup(yytext);}

[ \r\n\t]+                                  ;
"//"(.*)[\n]                                ;

print                                       return WRITE;
void                                        return BEGINN;
var                                         return VAR;
const                                       return CONSTANT;
if                                          return IF;
else                                        return ELSE;
while                                       return WHILE;
read                                        return READ;

({letra}|_)({letra}|{digito}|_)*            return idComprobacion();
{entero}                                    return enteroComprobacion(atoll(yytext));
"("                                         return LPAREN;
")"                                         return RPAREN;
";"                                         return SEMICOLON;
","                                         return COMMA;
"="                                         return ASSIGNOP;
"+"                                         return PLUSOP;
"-"                                         return MINUSOP;
"*"                                         return MULT;
"/"                                         return DIV;
"{"                                         return LBIGOTE;
"}"                                         return RBIGOTE;
[^_0-9a-zA-Z(){}\\\-+*=,;/\n\r" ]+          printf("Error Lexico: Error en carácter %s en la linea %d\n",yytext, yylineno );

%%
int enteroComprobacion(double numero)
{
    double max = pow(2,31);
    if(numero > max)
        printf("Error Lexico: Error, linea %d: el numero es mayor que 2^31\n", yylineno);
    yylval.lexema = strdup(yytext);
    return INTLITERAL;
}
int idComprobacion()
{
    if(yyleng > 16)
        printf("Error Lexico: Error, linea %d: longitud de la cadena mayor que 16\n", yylineno);
    yylval.lexema = strdup(yytext);
    return ID;
}

