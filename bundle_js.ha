use bufio;
use fmt;
use io;
use os;
use searchio;
use strings;

// STRATEGY
// Two passes are needed:
// - First pass: Scan the source files and create a dependency graph
// - Second pass: Bundle all needed files

type jsfile = struct {
	path: str,
	dependencies: []size, // indizes into dep_graph
	scanned: bool, // if the file was scanned for its dependencies already
};

type dep_graph = []jsfile;

fn dep_graph_free(g: dep_graph) void = {
	for (let i = 0z; i < len(g); i += 1) {
		free(g[i].path);
		free(g[i].dependencies);
	};
	free(g);
};

// html: true if the output can be inlined in a html script tag. This is
//       important because code like e.g.
//           let tag = "</script>";
//       has to be escaped.
// inputs are borrowed
fn tacker_js(inputpath: str, ofile: io::handle, html: bool) void = {
	let g: dep_graph = [];
	defer {
		for (let i = 0z; i < len(g); i += 1)
			free(g[i].dependencies);
		free(g);
	};
	dep_add(void, inputpath, &g);
	// TODO
	for (let i = 0z; i < len(g); i += 1) {
		fmt::printf("{}: {} - ", i, g[i].path)!;
		const dep = g[i].dependencies;
		for (let j = 0z; j < len(dep); j += 1) {
			fmt::printf("{},", dep[j])!;
		};
		fmt::println("")!;
	};
	dep_graph_free(g);
};

let p_req: searchio::pattern = searchio::pattern {...};
let p_newline: searchio::pattern = searchio::pattern {...};
let p_commentend: searchio::pattern = searchio::pattern {...};
let p_quotedouble: searchio::pattern = searchio::pattern {...};
let p_quotesingle: searchio::pattern = searchio::pattern {...};

@init fn init() void = {
	// "/" has to be recognized as regex literal or comment start
	p_req = searchio::compile(["require(", "/", "\"", "'", "`"]);
	p_newline = searchio::compile(["\n"]);
	p_commentend = searchio::compile(["*/"]);
	p_quotedouble = searchio::compile(["\""]);
	p_quotesingle = searchio::compile(["'"]);
};

@fini fn fini() void = {
	defer searchio::finish(p_req);
	defer searchio::finish(p_newline);
	defer searchio::finish(p_commentend);
	defer searchio::finish(p_quotedouble);
	defer searchio::finish(p_quotesingle);
};

// Add a connection frompath -> deppath to the dependency graph
// inputs are borrowed
fn dep_add(frompath: (str | void), deppath: str, graph: *dep_graph) void = {
	const g = *graph;
	let depindex = 0z;
	for (depindex < len(g) && g[depindex].path != deppath) depindex += 1;
	if (depindex == len(g)) {
		append(g, jsfile {
			path = strings::dup(deppath),
			dependencies = [],
			scanned = false
		});
	};
	// add link to the graph
	if (frompath is str) {
		const frompath = frompath: str;
		let fromindex = 0z;
		for (fromindex < len(g) && g[fromindex].path != frompath)
			fromindex += 1;
		append(g[fromindex].dependencies, depindex);
	};
	// scan deppath if neccessarry
	if (g[depindex].scanned == false) {
		g[depindex].scanned = true;
		*graph = g;
		dep_scan(deppath, graph);
	};
};

// Recursively scan and add a file to the dependency graph
// inputs are borrowed
fn dep_scan(inputpath: str, graph: *dep_graph) void = {
	const ifile = os::open(inputpath)!;
	defer io::close(ifile)!;
	// Read until require or comment or quote
	// if start of string literal etc was found (disabled require)
	let disabled = false;
	for (true) {
		const m = searchio::search(ifile, black_hole, p_req);
		if (m is size) {
			if (m == 0) {
				if (disabled == false) {
					const p = read_require(ifile,
						inputpath);
					if (p is str) {
						const p = p: str;
						defer free(p);
						const p = resolve_path_require(
							p, inputpath);
						defer free(p);
						dep_add(inputpath, p, graph);
					};
				} else {
					warningf("{}: file could contain skipped require() calls.", inputpath);
					break;
				};
			} else if (m == 1) {
				// "/*", "//" or "/regex/"
				const buf: [1]u8 = [' '];
				if (io::read(ifile, buf) is io::EOF) break;
				if (buf[0] == '/') {
					searchio::search(ifile, black_hole,
						p_newline);
				} else if (buf[0] == '*') {
					searchio::search(ifile, black_hole,
						p_commentend);
				} else disabled = true;
			} else {
				// '"', "'" or "`"
				disabled = true;
			};
		} else break;
	};
};

// Is returned if the require() is part of a longer identifier
type no = void;

// Parse the contents of a require() macro and return the file path.
// Return value has to be freed.
fn read_require(in: io::handle, path: str) (str | no) = {
	// Check if require() is part of another identifier like my_require()
	io::seek(in, -9, io::whence::CUR)!;
	const buf: [1]u8 = [' '];
	io::read(in, buf)!;
	io::seek(in, 8, io::whence::CUR)!;
	// this weird string contains all characters that are allowed in a js
	// source file but not in an identifier
	if (!strings::contains("\t\n\r !%&()*+,-./:;<=>?[]^{|}~", buf[0]: u32:
			rune))
		return no;

	io::read(in, buf)!;
	let broken = false;
	if (buf[0] == '"' || buf[0] == '\'') {
		let namebuf = bufio::dynamic(io::mode::WRITE);
		const pattern = if (buf[0] == '\'') p_quotesingle
			else p_quotedouble;
		searchio::search(in, &namebuf, pattern);
		let ret = strings::fromutf8(namebuf.buf);
		io::read(in, buf)!;
		if (buf[0] == ')') return ret;
	};
	fixed_fatalf("{}: broken require() call.", path);
	return ""; // will not be reached
};
