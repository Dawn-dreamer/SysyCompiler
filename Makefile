all: sysy_compiler

sysy_compiler: sysy.tab.cpp sysy.lex.cpp
	g++ -std=c++14 sysy.tab.cpp sysy.lex.cpp -g -o sysy_compiler

sysy.tab.cpp: sysy.y
	bison -d -o sysy.tab.cpp sysy.y -Wcounterexamples

sysy.lex.cpp: sysy.l
	flex -o sysy.lex.cpp sysy.l

clean:
	rm -f sysy.tab.cpp sysy.tab.hpp sysy.lex.cpp sysy_compiler