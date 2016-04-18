
C_FILES=central_monitor.c
PLUGIN=central_monitor

$(PLUGIN).so: central_monitor.c
	gcc -g -I `ocamlc -where` -Wall -o $(PLUGIN).so -shared -fPIC $(C_FILES)

clean:
	rm -f *.o *~ *.so
