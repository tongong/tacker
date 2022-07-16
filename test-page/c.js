// console.log(require("./a.js")); // illegal -> circular dependency
require("test-page/b.js");
exports.msg = ":)";
