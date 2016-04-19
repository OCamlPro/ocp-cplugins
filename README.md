# ocp-cplugins

A collection of plugins to use with the CAML_CPLUGINS feature:
* print_commands.so: print commands directly from the C plugin
* central_monitor.so: send commands to a central monitor through a socket

And a collection of tools to take advantage of them:
* ocp-show-build: display the OCaml commands called during a build

## Build and install

You need an OCaml version with CAML_CPLUGINS support (for now,
available in the switch `4.02.3+ocp` in
`github.com/lefessan/opam-repository-perso`)

```
make opam-deps
./configure
make
make install
```

## Usage

Dump commands on stderr:

```
ocp-show-build -- make
```

Dump command in a file `build.log`:

```
ocp-show-build -o build.log -- make
```
