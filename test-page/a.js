let testm = require("./b.js")
// console.log(testm.hello());

let r = "this require('b.js') will not be macro-expanded.";
console.log("hi from an imported script!");

function a() {
    // this should throw a warning
    console.log(require("test"));
};
