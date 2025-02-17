# Bobelniceanu Darius-Andrei - 331CC

all: main

main: lex.yy.c
	g++ lex.yy.c -o main -lfl

lex.yy.c: main.l
	flex main.l

clean:
	rm -f main lex.yy.c
