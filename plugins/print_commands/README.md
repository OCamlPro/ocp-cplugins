A simple plugin to log the OCaml commands called by a build process.

Use:

1/ Compile using `make` (you need OCaml in the PATH)

2/ Set the CAML_CPLUGINS variable

{{{
export CAML_CPLUGINS=`pwd`/print_commands.so
}}}

3/ In the project that you want to monitor, choose the file where the
build log should be stored:

{{{
export CAML_PRINT_COMMANDS_LOG=`pwd`/build.log
}}}

and then, call the build process:

{{{
make
}}}

The results should be available in the `build.log` file.
