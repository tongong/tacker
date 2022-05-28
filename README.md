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
      - `require(...)` with relative
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
