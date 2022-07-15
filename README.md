# tacker

`tacker` takes your files and staples them together. The goal of this project
is to be a simple web bundler independent of the disaster that is the modern
npm ecosystem. The main use case of `tacker` is bundling single page
applications into a single `.html` file for easier distribution. You can of
course also use it to quickly get access to modularity when developing
userscripts, to inline images into your static page, etc.

Advanced bundling and optimization techniques are not in scope
of `tacker` - try one of the bloated mainstream bundlers instead:
- webpack (75 dependencies)
- parcel (184 dependencies)
- browserify (175 dependencies)
- ...

`tacker` was written as an experimental project in the new
[hare programming language](https://harelang.org/).

## features
- entrypoints:
  - HTML
    - `<script src="...">` tags
    - `<link rel="stylesheet" href="...">` tags
    - binary data as base64 (`<audio>`, `<embed>`, `<img>`, `<source>`,
      `<track>`, `<video>`)
  - CSS
    - other style sheets (`@import url(...)`)
    - binary data as base64 (e.g. `background-image: url(...)`)
  - JS
    - a subset of CommonJS modules (see below for important drawbacks)
      - `require(...)`
      - `module.exports` and `exports`

The "conceptual module name space root" is the working directory. This means
that required paths which are not relative are resolved from the cwd. For
security reasons only files in the cwd can be bundled. This can be changed with
the `-p` option. Input and output file name stay relative to the cwd. The
`.js` in `require()` imports is optional.

`tacker` does not aim to be 100% spec-compliant. The goal is to work in all
common scenarios without laying to much emphasis on obscure edge cases. It is a
tacker after all - not an industrial robot. Though unlike a real-world tacker
your security should not be at hazard. Malicious source files can obviously
take over your bundled page but they can never take over your system.

## known bugs & missing features

### require()
CommonJS was chosen out of personal preference and its simplicity compared to
ES Modules (tree-shaking optimizations enabled by ES Modules would not be
implemented either way). The parser is rather simple though. To confirm to the
CommonJS spec arbitrary javascript expressions (as the argument to `require()`)
would need to be able to be evaluated at bundle-time. As `require` is just a
value and not special syntax the same is the case for the whole program as
every function could be possibly rebound to `require`. This requires the
complete execution of the program at bundle-time to be able to reason about
possible aliases to `require`. This is impossible and thus `require()` will be
treated as special syntax. This implementation (and in fact every CommonJS
bundler) is thus wrong but should work for every sane usage of `require()`.

The `require()` macro expects a string literal with single or double quotes as
single argument. Whitespace between `(` and `"`/`'`  or between `"`/`'` and `)`
is forbidden. Currently no escape sequences are allowed as this would add a lot
of complexity and is not needed for sane file names. This feature may be added
in the future.

Correctly expanding the `require()` macro requires recognizing string
literals (to not cause bugs by changing string content). This in turn requires
correctly recognizing regex literals as they could contain quote characters and
as far as I know this requires parsing the whole AST (how to decide if `/5/` is
a regex or part of an arithmetic expression?). A similar problem arises for
template literals. To avoid this complexity `tacker` only reads until reaching
the first character that could be start of a string, regex or template literal.
This means that module imports have to be at the top of each source file which
is the case already for most projects. All potentially skipped `require()`
calls will be announced as a warning.

### script end tags & regex literals
When inlining javascript in html, the script cannot contain script end tags
(`</script>`). To handle this all occurrences of `</script` will be replaced by
`<\/script`. This works in string literals and comments and should never occur
in normal code. I am however not sure about regex literals - there could be
very rare edge cases where these break.

### external resources
Bundling of external scripts, images, etc. is currently forbidden and `tacker`
will throw an error. There are two alternative behaviors:

1. Bundling the external resource: I think it is a bad idea to bundle random
   assets from the internet.
2. Allowing references to external resources without bundling them: This would
   be a better way of handling external resources but it creates a runtime
   dependency which is not very sustainable considering link rot.

It would be possible to enable behavior (2) via a command argument flag but I
currently do not see the point in implementing this feature.
