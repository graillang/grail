# Modules and source files

A module file declares its name; `use` names a dependency and `module::name` qualifies a reference.
The executable entry file may omit its module declaration, as hello world does.
This example calls a public function in another file.

{{example:modules}}

The supporting Grail and Rust files are included in the comparison above.

Unlike an implicit package loader, today's native compiler needs every source file explicitly.
The example manifest lists its helper, and `just book-run modules` supplies both files plus the
Grail runtime. The entry file comes first. `use arithmetic` by itself does not search the disk.

The Grail-written compiler is the sole implementation; declarations, generic bodies and
dependencies are checked before an output artifact is replaced.

**Try it:** add another helper and change the call. Keep all source files in the invocation.
