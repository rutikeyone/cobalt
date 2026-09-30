# cobalt_analyzer

Shared static analysis layer for [Cobalt](https://github.com/rutikeyone/cobalt). It turns annotated
Dart source into a typed intermediate representation.

Both `cobalt_generator` and `cobalt_lint` consume this package, so a declaration is parsed by one
implementation rather than two that drift apart. It depends on `analyzer` but deliberately not on
`build` or on the plugin API, so the lint plugin does not pull the build system into the analysis
server.

This is an internal package, and its API is **not covered by semantic versioning**: its models and
parsers change whenever the generator or the lint plugin needs them to, in any release. It is
published because those two depend on it, and its version moves in lockstep with theirs. Depend on
`cobalt_generator` or `cobalt_lint`; if you build your own tooling on Cobalt's annotations on top of
this package, pin an exact version.
