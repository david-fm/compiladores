%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include "listaSimbolos.h"
    #include "listaCodigo.h"
    

    Lista tablaSimb;
    int contCadenas=0;
    int * reg;
    extern int yylineno;
    extern char *yytext;
    Tipo tipo;
    int contador_etiq = 0;
    int error = 0;
    
    void yyerror();
    extern int yylex();
    int perteneceTablaS(char * id);
    int esConstante(char * id);
    void imprimirTablaS();
    void anadeEntrada(char * id, Tipo tipo, int valor);
    int * iniRegistro();
    void liberarReg(char * toFree);
    char * obtenerReg();
    void imprimirCodigo(ListaC codigo);
    char *nuevaEtiqueta();
%}
%union{
    char * lexema;
    ListaC codigo;
}

%token BEGINN END READ WRITE LPAREN RPAREN SEMICOLON COMMA ASSIGNOP PLUSOP MINUSOP REALLIT LBIGOTE RBIGOTE VAR CONSTANT IF ELSE WHILE MULT DIV
%token <lexema> INTLITERAL
%token <lexema> ID
%token <lexema> STRING
%type <codigo> expression statement asig statement_list print_item print_list read_list identifier_list declarations program

%left PLUSOP MINUSOP             // Derivaciones por la izquierda al aparecer estos op
%left MULT DIV
%left UMENOS

%expect 1                       //  Simplemente pasa del conflicto, dejando que bison se encargue de el
%%
program : {tablaSimb = creaLS(); reg = iniRegistro();}  BEGINN ID LPAREN RPAREN LBIGOTE declarations statement_list RBIGOTE 
    {
        if(!error)
        {
            imprimirTablaS(); 
            printf("\n###############\n#Seccion de codigo\n.text\n.globl main\nmain:\n"); 
            imprimirCodigo($7); 
            imprimirCodigo($8); 
            printf("\nli $v0, 10\nsyscall");
        }
        liberaLC($7); 
        liberaLC($8); 
        liberaLS(tablaSimb); 
    };
declarations :  declarations VAR {tipo = VARIABLE;} identifier_list SEMICOLON   {  $$ = $1; concatenaLC($$,$4); liberaLC($4); }
    | declarations CONSTANT {tipo = CONSTANTE;} identifier_list SEMICOLON       {  $$ = $1; concatenaLC($$,$4); liberaLC($4); }
    |                                                                           {  $$=creaLC(); }
    ;
identifier_list :   asig            {  $$=$1; }
    |   identifier_list COMMA asig  {  $$ = $1; concatenaLC($$,$3); liberaLC($3); }
    ;
asig    :   ID {
                if (!perteneceTablaS($1)) {anadeEntrada($1, tipo,0); }
                else {printf("Error Semantico: Variable %s ya declarada \n",$1); error = 1; }
                $$=creaLC();
                }
    |   ID ASSIGNOP expression {if (!perteneceTablaS($1))
                                {
                                    anadeEntrada($1, tipo,0);
                                    char * aux = malloc(sizeof(char)*(strlen($1)+1)) ;
                                    aux[0] = '_';
                                    PosicionListaC pos = finalLC($3);
                                    Operacion nueva;
                                    nueva.op = "sw";
                                    nueva.res = recuperaResLC($3);
                                    nueva.arg1 = strcat(aux,$1);
                                    nueva.arg2 = NULL;
                                    insertaLC($3, pos, nueva);
                                    $$ = $3;
                                    liberarReg(nueva.res);
                                }
                                else{ 
                                    printf("Error Semantico: Variable %s ya declarada \n",$1);
                                    $$=creaLC();
                                    error = 1;
                                }}
    ;
statement_list  :   statement_list statement                    {  $$ = $1; concatenaLC($$,$2); liberaLC($2);  }
    |                                                           {  $$ = creaLC(); }
    ;
statement   :   ID ASSIGNOP expression SEMICOLON                {if (!perteneceTablaS($1)){ printf ("Error Semantico: Variable %s no declarada\n", $1); $$=creaLC(); error = 1;}
                                                                    else if (esConstante($1)){ printf ("Error Semantico: Asignación a constante\n"); $$=creaLC(); error = 1;}
                                                                        else
                                                                        {
                                                                            char * aux = malloc(sizeof(char)*(strlen($1)+1)) ;
                                                                            aux[0] = '_';
                                                                            PosicionListaC pos = finalLC($3);


                                                                            Operacion nueva;
                                                                            nueva.op = "sw";
                                                                            nueva.res = recuperaResLC($3);
                                                                            nueva.arg1 = strcat(aux,$1);
                                                                            nueva.arg2 = NULL;
                                                                            insertaLC($3, pos, nueva);
                                                                            $$ = $3;
                                                                            liberarReg(nueva.res);
                                                                        }
                                                                }
    | LBIGOTE statement_list RBIGOTE                            { $$ = $2; }
    | IF LPAREN expression RPAREN statement ELSE statement     {$$ = $3;

                                                                PosicionListaC pos = finalLC($$);
                                                                
                                                                Operacion nueva;
                                                                nueva.op = "beqz";
                                                                nueva.res = recuperaResLC($$);
                                                                char * etiq = nuevaEtiqueta();
                                                                nueva.arg1 = etiq;
                                                                nueva.arg2 = NULL;
                                                                insertaLC($$, pos, nueva);

                                                                liberarReg(recuperaResLC($$));

                                                                concatenaLC($$, $5);
                                                                liberaLC($5);

                                                                char * etiq2 = nuevaEtiqueta();
                                                                
                                                                pos = finalLC($$);
                                                                Operacion incondicional;
                                                                incondicional.op = "b";
                                                                incondicional.res = etiq2;
                                                                incondicional.arg1 = NULL;
                                                                incondicional.arg2 = NULL;
                                                                insertaLC($$, pos, incondicional);

                                                                pos = finalLC($$);
                                                                Operacion etiqueta;
                                                                char * aux = strdup(etiq);
                                                                long unsigned int t = strlen(aux);
                                                                etiqueta.op = realloc(aux, sizeof(char)*(t+2));
                                                                etiqueta.op[t] = ':';
                                                                etiqueta.op[t+1] = '\0';
                                                                etiqueta.res = NULL;
                                                                etiqueta.arg1 = NULL;
                                                                etiqueta.arg2 = NULL;
                                                                insertaLC($$, pos, etiqueta);

                                                                concatenaLC($$, $7);
                                                                liberaLC($7);

                                                                pos = finalLC($$);
                                                                Operacion etiqueta2;
                                                                char * aux2 = strdup(etiq2);
                                                                long unsigned int t2 = strlen(aux2);
                                                                etiqueta2.op = realloc(aux2, sizeof(char)*(t2+2));
                                                                etiqueta2.op[t2] = ':';
                                                                etiqueta.op[t+1] = '\0';
                                                                etiqueta2.res = NULL;
                                                                etiqueta2.arg1 = NULL;
                                                                etiqueta2.arg2 = NULL;
                                                                insertaLC($$, pos, etiqueta2);
                                                                }
    | IF LPAREN expression RPAREN statement                    {$$ = $3;

                                                                PosicionListaC pos = finalLC($$);
                                                                
                                                                Operacion nueva;
                                                                nueva.op = "beqz";
                                                                nueva.res = recuperaResLC($$);
                                                                char * etiq = nuevaEtiqueta();
                                                                nueva.arg1 = etiq;
                                                                nueva.arg2 = NULL;
                                                                insertaLC($$, pos, nueva);

                                                                liberarReg(recuperaResLC($$));

                                                                concatenaLC($$, $5);
                                                                liberaLC($5);

                                                                pos = finalLC($$);
                                                                Operacion etiqueta;
                                                                char * aux = strdup(etiq);
                                                                long unsigned int t = strlen(aux);
                                                                etiqueta.op = realloc(aux, sizeof(char)*(t+1));
                                                                etiqueta.op[t] = ':';
                                                                etiqueta.res = NULL;
                                                                etiqueta.arg1 = NULL;
                                                                etiqueta.arg2 = NULL;
                                                                insertaLC($$, pos, etiqueta);
                                                                }
    | WHILE LPAREN expression RPAREN statement                  {$$ = creaLC();

                                                                char * etiq2 = nuevaEtiqueta();
                                                                PosicionListaC pos = finalLC($$);
                                                                Operacion etiqueta2;
                                                                char * aux2 = strdup(etiq2);
                                                                long unsigned int t2 = strlen(aux2);
                                                                etiqueta2.op = realloc(aux2, sizeof(char)*(t2+1));
                                                                etiqueta2.op[t2] = ':';
                                                                etiqueta2.res = NULL;
                                                                etiqueta2.arg1 = NULL;
                                                                etiqueta2.arg2 = NULL;
                                                                insertaLC($$, pos, etiqueta2);

                                                                concatenaLC($$, $3);
                                                                

                                                                pos = finalLC($$);
                                                                
                                                                Operacion nueva;
                                                                nueva.op = "beqz";
                                                                nueva.res = recuperaResLC($3);
                                                                char * etiq = nuevaEtiqueta();
                                                                nueva.arg1 = etiq;
                                                                nueva.arg2 = NULL;
                                                                insertaLC($$, pos, nueva);

                                                                liberarReg(recuperaResLC($3));
                                                                liberaLC($3);

                                                                concatenaLC($$, $5);
                                                                liberaLC($5);

                                                                pos = finalLC($$);
                                                                Operacion incondicional;
                                                                incondicional.op = "b";
                                                                incondicional.res = etiq2;
                                                                incondicional.arg1 = NULL;
                                                                incondicional.arg2 = NULL;
                                                                insertaLC($$, pos, incondicional);

                                                                pos = finalLC($$);
                                                                Operacion etiqueta;
                                                                char * aux = strdup(etiq);
                                                                long unsigned int t = strlen(aux);
                                                                etiqueta.op = realloc(aux, sizeof(char)*(t+1));
                                                                etiqueta.op[t] = ':';
                                                                etiqueta.res = NULL;
                                                                etiqueta.arg1 = NULL;
                                                                etiqueta.arg2 = NULL;
                                                                insertaLC($$, pos, etiqueta);
                                                                }
    | WRITE print_list SEMICOLON                                {  $$ = $2; }
    | READ read_list SEMICOLON                                  {  $$ = $2; }
    ;
print_list  : print_item                    {  $$ = $1; }
    |   print_list COMMA print_item         {  $$ = $1; concatenaLC($$,$3); liberaLC($3);  }
    ;
print_item  : expression                   {$$=$1;
                                            PosicionListaC pos = finalLC($$);
                                            Operacion nueva;
                                            nueva.op = "li";
                                            nueva.res = "$v0";
                                            nueva.arg1 = "1";
                                            nueva.arg2 = NULL;
                                            Operacion move;
                                            move.op = "move";
                                            move.res = "$a0";
                                            move.arg1 = recuperaResLC($$);
                                            move.arg2 = NULL;
                                            Operacion syscall;
                                            syscall.op = "syscall";
                                            syscall.res = NULL;
                                            syscall.arg1 = NULL;
                                            syscall.arg2 = NULL;
                                            insertaLC($$, pos, nueva);
                                            pos = finalLC($$);
                                            insertaLC($$, pos, move);
                                            pos = finalLC($$);
                                            insertaLC($$, pos, syscall);
                                            liberarReg(nueva.res);

                                            }
    | STRING                               {anadeEntrada($1,CADENA,contCadenas); 

                                            $$=creaLC();
                                            PosicionListaC pos = finalLC($$);

                                            Operacion nueva;
                                            nueva.op = "li";
                                            nueva.res = "$v0";
                                            nueva.arg1 = "4";
                                            nueva.arg2 = NULL;

                                            Operacion move;
                                            move.op = "la";
                                            move.res = "$a0";
                                            char aux [11] = "$str";
                                            char number [5];
                                            sprintf(number,"%d", contCadenas);
                                            strcat(aux,number);
                                            char * strInHeap = malloc(sizeof(char)*11);
                                            strcpy(strInHeap,aux);

                                            move.arg1 = strInHeap;
                                            move.arg2 = NULL;

                                            Operacion syscall;
                                            syscall.op = "syscall";
                                            syscall.res = NULL;
                                            syscall.arg1 = NULL;
                                            syscall.arg2 = NULL;

                                            insertaLC($$, pos, nueva);
                                            pos = finalLC($$);
                                            insertaLC($$, pos, move);
                                            pos = finalLC($$);
                                            insertaLC($$, pos, syscall);
                                            liberarReg(nueva.res);

                                            contCadenas++;}
    ;
read_list   : ID                            {if (!perteneceTablaS($1)){ printf("Error Semantico: Variable %s no declarada \n", $1); $$=creaLC(); error = 1;}
                                                else if (esConstante($1)){ printf("Error Semántico: Asignación a constante\n"); $$=creaLC(); error = 1;}
                                                    else{
                                                        $$=creaLC();
                                                        PosicionListaC pos = finalLC($$);
                                                        Operacion nueva;
                                                        nueva.op = "li";
                                                        nueva.res = "$v0";
                                                        nueva.arg1 = "5";
                                                        nueva.arg2 = NULL;
                                                        
                                                        Operacion syscall;
                                                        syscall.op = "syscall";
                                                        syscall.res = NULL;
                                                        syscall.arg1 = NULL;
                                                        syscall.arg2 = NULL;

                                                        char * aux = malloc(sizeof(char)*(strlen($1)+1));
                                                        aux[0] = '_';
                                                        Operacion sw;
                                                        sw.op = "sw";
                                                        sw.res = "$v0";
                                                        sw.arg1 = strcat(aux,$1);
                                                        sw.arg2 = NULL;

                                                        insertaLC($$, pos, nueva);
                                                        pos = finalLC($$);
                                                        insertaLC($$, pos, syscall);
                                                        pos = finalLC($$);
                                                        insertaLC($$, pos, sw);                                                        
                                                    }
                                            }
    | read_list COMMA ID                    {if (!perteneceTablaS($3)){ printf("Error Semántico: Variable %s no declarada \n", $3); $$=creaLC(); error = 1;}
                                                else if (esConstante($3)){ printf("Error Semántico: Asignación a constante\n"); $$=creaLC(); error = 1;}
                                                    else
                                                    {
                                                        $$=$1;
                                                        PosicionListaC pos = finalLC($$);
                                                        Operacion nueva;
                                                        nueva.op = "li";
                                                        nueva.res = "$v0";
                                                        nueva.arg1 = "5";
                                                        nueva.arg2 = NULL;
                                                        
                                                        Operacion syscall;
                                                        syscall.op = "syscall";
                                                        syscall.res = NULL;
                                                        syscall.arg1 = NULL;
                                                        syscall.arg2 = NULL;

                                                        char * aux = malloc(sizeof(char)*(strlen($3)+1));
                                                        aux[0] = '_';
                                                        Operacion sw;
                                                        sw.op = "sw";
                                                        sw.res = "$v0";
                                                        sw.arg1 = strcat(aux,$3);
                                                        sw.arg2 = NULL;

                                                        insertaLC($$, pos, nueva);
                                                        pos = finalLC($$);
                                                        insertaLC($$, pos, syscall);
                                                        pos = finalLC($$);
                                                        insertaLC($$, pos, sw);                                                      
                                                    } }
    ;
expression  : expression PLUSOP expression  {   $$ = $1; 
                                                concatenaLC($$,$3);
                                                Operacion oper; 
                                                oper.op = "add"; 
                                                oper.res = recuperaResLC($1);
                                                oper.arg1 = recuperaResLC($1); 
                                                oper.arg2 = recuperaResLC($3);
                                                insertaLC($$,finalLC($$),oper);
                                                liberaLC($3);
                                                liberarReg(oper.arg2);
                                            }
    | expression MINUSOP expression         {   $$ = $1; concatenaLC($$,$3);
                                                Operacion oper; 
                                                oper.op = "sub"; 
                                                oper.res = recuperaResLC($1);
                                                oper.arg1 = recuperaResLC($1); 
                                                oper.arg2 = recuperaResLC($3);
                                                insertaLC($$,finalLC($$),oper);
                                                liberaLC($3);
                                                liberarReg(oper.arg2);
                                            }
    | expression MULT expression            {   $$ = $1; concatenaLC($$,$3);
                                                Operacion oper; 
                                                oper.op = "mul"; 
                                                oper.res = recuperaResLC($1);
                                                oper.arg1 = recuperaResLC($1); 
                                                oper.arg2 = recuperaResLC($3);
                                                insertaLC($$,finalLC($$),oper);
                                                liberaLC($3);
                                                liberarReg(oper.arg2);
                                            }
    | expression DIV expression             {   $$ = $1; concatenaLC($$,$3);
                                                Operacion oper; 
                                                oper.op = "div"; 
                                                oper.res = recuperaResLC($1);
                                                oper.arg1 = recuperaResLC($1); 
                                                oper.arg2 = recuperaResLC($3);
                                                insertaLC($$,finalLC($$),oper);
                                                liberaLC($3);
                                                liberarReg(oper.arg2);
                                            }
    | MINUSOP expression %prec UMENOS       {   PosicionListaC pos = finalLC($2);
                                                Operacion ult = recuperaLC($2, pos);
                                                Operacion nueva;
                                                nueva.op = "neg";
                                                nueva.res = ult.res;
                                                nueva.arg1 = NULL;
                                                nueva.arg2 = NULL;
                                                insertaLC($2, pos, nueva);
                                                $$ = $2;
                                            }
    | LPAREN expression RPAREN              {   $$ = $2; }
    | ID                                    {   if (!perteneceTablaS($1)){ printf("Error Semantico: Variable %s no declarada \n", $1); $$=creaLC(); error = 1;}
                                                    else
                                                    {
                                                        char * aux = malloc(sizeof(char)*(strlen($1)+1));
                                                        aux[0] = '_';
                                                        $$ = creaLC();
                                                        Operacion oper;
                                                        oper.op = "lw";
                                                        oper.res = obtenerReg();
                                                        oper.arg1 = strcat(aux,$1);
                                                        oper.arg2 = NULL;
                                                        insertaLC($$,finalLC($$),oper);
                                                        guardaResLC($$,oper.res);
                                                    }
                                            }
    | INTLITERAL                            {   $$ = creaLC();
                                                Operacion oper;
                                                oper.op = "li";
                                                oper.res = obtenerReg();
                                                oper.arg1 = $1;
                                                oper.arg2 = NULL;
                                                insertaLC($$,finalLC($$),oper);
                                                guardaResLC($$,oper.res);
                                            }                            
    ;
%%
void yyerror()
{
    printf("Error sintactico: Error en la linea %d\n", yylineno);
    error = 1;
}
int perteneceTablaS(char * id)
{
    PosicionLista buscado = buscaLS(tablaSimb, id);
    if( buscado != finalLS(tablaSimb))
        return 1;
    return 0;
}
int esConstante(char * id)
{
    PosicionLista buscado = buscaLS(tablaSimb, id);
    Simbolo s = recuperaLS(tablaSimb, buscado);
    if( s.tipo == CONSTANTE)
        return 1;
    return 0;
}
void anadeEntrada(char * id, Tipo tipo, int valor)
{
    Simbolo s;
    s.nombre = id;
    s.tipo = tipo;
    s.valor = valor;
    if(tipo == CADENA)
        s.valor = contCadenas;
    insertaLS(tablaSimb, finalLS(tablaSimb), s);
}
void imprimirTablaS()
{
    PosicionLista ini = inicioLS(tablaSimb);
    PosicionLista fin = finalLS(tablaSimb);
    Simbolo actual;
    printf("###################\n");
    printf("# Sección de datos\n");
    printf(".data\n");
    while(ini != fin)
    {
        actual = recuperaLS(tablaSimb, ini);
        if(actual.tipo == CADENA)
        {
            printf("$str%d:\n", actual.valor);
            printf(".asciiz \"%s\"\n",actual.nombre);
        }
        else if(actual.tipo == VARIABLE || actual.tipo == CONSTANTE)
        {
            printf("_%s:\n", actual.nombre);
            printf(".word 0\n");
        }
        ini = siguienteLS(tablaSimb, ini);
    }
}
int * iniRegistro()
{
    int * devolver = malloc(sizeof(int) * 10);
    for(int i = 0; i<10; ++i)
        devolver[i] = 0;
    return devolver;
}
char * obtenerReg()
{
    char * res = malloc(sizeof(char)*3);
    int hay = 0;
    res[0] = '$';
    res[1] = 't';
    for(int i = 0; i< 10; ++i)
    {
        if(reg[i] == 0)
        {
            
            reg[i] = 1;
            res [2] = i+'0';
            hay = 1;
            break;
        }
    }
    if(!hay)
    {
        printf("Error Semantico: No hay registros disponibles.");
        error = 1;
    } 

    return res;
}
void liberarReg(char * toFree)
{
    if(toFree==NULL|| strcmp(toFree,"")==0)
        return;
    int pos = atoi(&toFree[2]);
    reg[pos] = 0;
}
void imprimirCodigo(ListaC codigo) {
    PosicionListaC p = inicioLC(codigo);
    while (p != finalLC(codigo)) {
        Operacion oper = recuperaLC(codigo,p);
        printf("%s",oper.op);
        if (oper.res) printf(" %s",oper.res);
        if (oper.arg1) printf(",%s",oper.arg1);
        if (oper.arg2) printf(",%s",oper.arg2);
        printf("\n");
        p = siguienteLC(codigo,p);
    }
}
char *nuevaEtiqueta() 
{
    char aux[16];
    sprintf(aux,"$l%d",contador_etiq++);
    return strdup(aux);
}