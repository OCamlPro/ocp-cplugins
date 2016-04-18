
example.so: example.c
	gcc -I `ocamlc -where` -Wall -o example.so -shared -fPIC example.c

clean:
	rm -f *.o *~ *.so
