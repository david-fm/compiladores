a.out: lex.yy.c main.c miniC.tab.c listaSimbolos.h listaSimbolos.c listaCodigo.c
	gcc lex.yy.c main.c miniC.tab.c listaSimbolos.h listaSimbolos.c listaCodigo.c -lfl


miniC.tab.c miniC.tab.h: miniC.y 
	bison -d miniC.y 

lex.yy.c: lexElPro.l miniC.tab.h
	flex lexElPro.l

clean:
	rm lex.yy.c a.out miniC.tab.c miniC.tab.h debugeable 

cleanPruebas:
	rm -r pruebas

debug: debugeable
	gdb debugeable

mac: lex.yy.c main.c miniC.tab.c listaSimbolos.h listaSimbolos.c listaCodigo.c
	gcc lex.yy.c main.c miniC.tab.c listaSimbolos.h listaSimbolos.c listaCodigo.c -ll
	
debugeable: lex.yy.c main.c miniC.tab.c listaSimbolos.h listaSimbolos.c listaCodigo.c
	gcc lex.yy.c main.c miniC.tab.c listaSimbolos.h listaSimbolos.c listaCodigo.c -g -lfl -o ejecutable

run: a.out
	./a.out test_sem1.mc

ejemplos: a.out
	mkdir pruebas
	./a.out prueba > pruebas/resPrueba
	./a.out prueba_sintactico1.mc > pruebas/resPrueba_sintactico1.mc
	./a.out test_lex.mc > pruebas/resTest_lex.mc
	./a.out test_sem1.mc > pruebas/resTest_sem1.mc
	./a.out test_sem2.txt > pruebas/resTest_sem2.txt
	./a.out test_sem3.txt > pruebas/resTest_sem3.txt
	./a.out test_sem4.txt > pruebas/resTest_sem4.txt