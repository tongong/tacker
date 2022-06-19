# tacker

`tacker` takes your files and staples them together. The goal of this project
is to be a simple web bundler independent of the disaster that is the modern
npm ecosystem. Advanced bundling and optimization techniques are not in scope
of `tacker` - try one of the bloated mainstream bundlers instead:
- webpack (75 dependencies)
- parcel (184 dependencies)
- browserify (175 dependencies)
- ...

`tacker` was written as an experimental project in the new `hare` programming
language.

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
    - a subset of CommonJS modules
      - `require(...)`
      - `module.exports` and `exports`
    - binary data as base64 through custom `requireBinary(...)` function

CommonJS was chosen out of personal preference and its simplicity compared to
ES Modules (tree-shaking optimizations enabled by ES Modules would not be
implemented either way). The parser is rather simple though. To confirm to the
CommonJS spec arbitrary javascript expressions (as the argument to `require()`)
would need to be able to be evaluated at bundle-time. As `require` is just a
value and not special syntax the same is the case for the whole program as
every function could be possibly rebound to `require`. This requires the
complete execution of the program at bundle-time to be able to reason about
possible aliases to `require`. This is impossible and thus `require()` will be
treated as special syntax. This implementation is thus wrong but should work
for every sane usage of `require()`.

The "conceptual module name space root" is the working directory. This means
that required paths which are not relative are resolved from the cwd. For
security reasons only files in the cwd can be bundled. This can be changed with
the `-p` option. Input and output file name stay relative to the cwd.

`tacker` does not aim to be 100% spec-compliant. The goal is to work in all
common scenarios without laying to much emphasis on obscure edge cases. It is a
tacker after all - not an industrial robot. Though unlike a real-world tacker
your security should not be at hazard. In the case of javascript malicious
source files can obviously take over your bundle but they should never take
over your system.
