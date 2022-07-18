// </script>
let testm = require("./b.js")
require("./c.js")
require("./scripttest");

console.log("</script> tags work!");

let r = "this require('b.js') will not be macro-expanded.";
console.log("hi from an imported script!");

function a() {
    // this should throw a warning
    console.log(require("test"));
};

console.log(testm);
window.testm = testm;
