
print_commands.so: print_commands.c
	gcc -I `ocamlc -where` -Wall -o print_commands.so -shared -fPIC print_commands.c

clean:
	rm -f *.o *~ *.so
