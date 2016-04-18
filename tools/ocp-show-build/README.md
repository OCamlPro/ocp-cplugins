
# Usage:

ocp-show-build [OPTIONS] COMMAND

ocp-show-build can be used to display the OCaml commands called during
a build. The OCaml runtime must support use of CAML_CPLUGINS, and
especially the central_monitor.so plugin must be in use.

Available options:
  -o FILE    Store results in FILE
  --all      Print all messages
  -- COMMAND Command to call
  -help      Display this list of options
  --help     Display this list of options

# Depends

You need support for `CAML_CPLUGINS`. For that, you can use the
`4.02.3+ocp` compiler in `github.com/lefessan/opam-repository-perso`

You also need:
* lwt
* ocp-build

# Build

{{{
make opam-deps
make
}}}



