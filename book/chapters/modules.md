# Modules and source files

A module file declares its name; `use` names a dependency and `module::name` qualifies a reference.
The executable entry file may omit its module declaration, as hello world does.
This example calls a public function in another file.

{{example:modules}}

The helper module is:

{{source:examples/arithmetic.grl}}

Unlike an implicit package loader, today's native compiler needs every source file explicitly.
The example manifest lists its helper, and `just book-run modules` supplies both files plus the
Grail runtime. The entry file comes first. `use arithmetic` by itself does not search the disk.

Put type declarations before functions for compatibility with the seed frontend. Public generic
functions and type-only modules are supported, but the native checker and seed are not identical
implementations; do not assume every design-document feature is available in both.

**Try it:** add another helper and change the call. Keep all source files in the invocation.
