use bufio;
use bytes;
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
	const s = script_guard(ofile);
	if (html) ofile = &s;
	let g: dep_graph = [];
	defer dep_graph_free(g);
	dep_add(void, inputpath, &g);
	const sorting = sort_kahn(g, inputpath);
	defer free(sorting);
	fmt::fprintln(ofile, "(function() {")!;
	for (let i = 0z; i < len(sorting); i += 1) {
		fmt::fprintfln(ofile, "const _tacker{} = (function() {{", sorting[i])!;
		fmt::fprintln(ofile, "const module = { exports: {} }, exports = module.exports;")!;
		emit_bundled(g[sorting[i]].path, ofile, g);
		fmt::fprintln(ofile, "\nreturn module.exports;")!;
		fmt::fprintln(ofile, "})();")!;
	};
	fmt::fprintln(ofile, "})();")!;
	if (html) io::close(ofile)!;
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
	for (true) {
		const m = searchio::search(ifile, black_hole, p_req);
		if (m is size) {
			if (m == 0) {
				const p = read_require(ifile, inputpath);
				if (p is str) {
					const p = p: str;
					defer free(p);
					const p = resolve_path_require(p,
						inputpath);
					defer free(p);
					dep_add(inputpath, p, graph);
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
				} else break;
			} else break; // '"', "'" or "`"
		} else break;
	};
};


// Parse the contents of a require() macro and return the file path.
// Return value has to be freed.
// Return void if require() is part of a longer identifier
fn read_require(in: io::handle, path: str) (str | void) = {
	const buf: [1]u8 = [' '];
	// Check if require() is part of another identifier like my_require()
	if (!(io::seek(in, -9, io::whence::CUR) is io::error)) {
		io::read(in, buf)!;
		io::seek(in, 8, io::whence::CUR)!;
		// this weird string contains all characters that are allowed in
		// a js source file but not in an identifier
		if (!strings::contains("\t\n\r !%&()*+,-./:;<=>?[]^{|}~",
				buf[0]: u32: rune))
			return void;
	};

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


// Kahn's algorithm https://en.wikipedia.org/wiki/Topological_sorting
// Return value has to be freed
fn sort_kahn(graph: dep_graph, entrypath: str) []size = {
	let sorting: []size = [];
	for (let i = 0z; i < len(graph); i += 1) {
		graph[i].scanned = false;
	};
	for (true) {
		// Find file without dependencies
		let f = 0z; // index into graph
		for (f < len(graph); f += 1) {
			const deps = graph[f].dependencies;
			let no_deps = true;
			for (let i = 0z; i < len(deps); i += 1) {
				// Deleted edges in graph will be set to -1
				if (deps[i] != -1) {
					no_deps = false;
					break;
				};
			};
			if (no_deps && !graph[f].scanned) break;
		};
		if (f == len(graph)) {
			// If no file without dependencies can be found -> error
			fixed_fatalf("{}: circular javascript dependencies.",
				entrypath);
		};
		// Delete dependencies for dependent files
		for (let i = 0z; i < len(graph); i += 1) {
			let deps = graph[i].dependencies;
			for (let j = 0z; j < len(deps); j += 1) {
				if (deps[j] == f) deps[j] = -1;
			};
		};
		graph[f].scanned = true;
		append(sorting, f);
		// If all files are sorted -> stop
		if (len(sorting) == len(graph)) return sorting;
	};
	return []; // will not be reached
};


// Resolve require() and add files to the bundle
// very similar to dep_scan()
fn emit_bundled(inputpath: str, ofile: io::handle, graph: dep_graph) void = {
	const ifile = os::open(inputpath)!;
	defer io::close(ifile)!;

	// Read until require or comment or quote
	for (true) {
		const m = searchio::search(ifile, ofile, p_req);
		if (m is size) {
			const m = m: size;
			if (m == 0) {
				const p = read_require(ifile,
					inputpath);
				if (p is str) {
					const p = p: str;
					defer free(p);
					const p = resolve_path_require(
						p, inputpath);
					defer free(p);
					let i = 0z;
					// could break if files are
					// changed in race condition
					for (graph[i].path != p) i += 1;
					fmt::fprintf(ofile, "_tacker{}", i)!;
				} else fmt::fprint(ofile, "require(")!;
			} else if (m == 1) {
				// "/*", "//" or "/regex/"
				fmt::fprint(ofile, "/")!;
				const buf: [1]u8 = [' '];
				if (io::read(ifile, buf) is io::EOF) break;
				io::writeall(ofile, buf)!;
				if (buf[0] == '/') {
					searchio::search(ifile, ofile,
						p_newline);
					fmt::fprint(ofile, "\n")!;
				} else if (buf[0] == '*') {
					searchio::search(ifile, ofile,
						p_commentend);
					fmt::fprint(ofile, "*/")!;
				} else break;
			} else {
				// '"', "'" or "`"
				fmt::fprint(ofile, p_req.original[m])!;
				break;
			};
		} else break;
	};
	search_require(ifile, ofile, inputpath);
};

// Find potentially lost require() calls while piping everything from in to out.
fn search_require(in: io::handle, out: io::handle, inputpath: str) void = {
	const re = strings::toutf8("require("); // 7 = len(re) - 1
	static let buf_ext: [4096 + 7]u8 = [0...];
	let buf = buf_ext[7..];
	for (true) {
		match (io::read(in, buf)!) {
		case let n: size => {
			io::writeall(out, buf[..n])!;
			if (bytes::contains(buf[0..n], re)) {
				warningf("{}: file could contain skipped require() calls.",
					inputpath);
				break;
			};
			buf_ext[..7] = buf_ext[n..n+7];
		};
		case io::EOF => break;
		};
	};
	io::copy(out, in)!;
};

type sgstream = struct {
	stream: io::stream,
	sink: io::handle,
	buffered: size, // number of buffered bytes in script
};

const sg_vtable: io::vtable = io::vtable {
	writer = &sg_write,
	closer = &sg_close,
	...
};

// Create a writeonly handle that replaces </script with <\/script
fn script_guard(sink: io::handle) sgstream = {
	return sgstream {
		stream = &sg_vtable,
		sink = sink,
		buffered = 0,
	};
};

const scriptbuf: [8]u8 = ['<', '/', 's', 'c', 'r', 'i', 'p', 't'];

fn sg_write(st: *io::stream, buf_orig: const []u8) (size | io::error) = {
	const st = st: *sgstream;
	let buf = buf_orig;
	// IDEA
	// if the buffer size is smaller than the rest of the scriptbuf
	// - test if the buffer fits into the rest of the scriptbuf
	// - if not test if the buffer is start of a new script string
	// if the buffer size is bigger or equal to the rest of the scriptbuf
	// - check if the scriptbuf is finished
	const scriptleft = scriptbuf[st.buffered..];
	if (len(buf) < len(scriptleft)) {
		if (bytes::hasprefix(scriptleft, buf)) {
			st.buffered += len(buf);
		} else {
			io::writeall(st.sink, scriptbuf[..st.buffered])!;
			if (bytes::hasprefix(scriptbuf, buf)) {
				st.buffered = len(buf);
			} else {
				io::writeall(st.sink, buf)!;
			};
		};
	} else {
		if (bytes::hasprefix(buf, scriptleft)) {
			buf = buf[len(scriptleft)..];
			io::writeall(st.sink, strings::toutf8("<\\/script"))!;
		} else {
			io::writeall(st.sink, scriptbuf[..st.buffered])!;
		};
		let written = false;
		for (let i = 1z; i < len(scriptbuf); i += 1) {
			if (len(buf) > i && bytes::hassuffix(buf,
					scriptbuf[..i])) {
				st.buffered = i;
				sg_write_single(st.sink, buf[..len(buf)-i]);
				written = true;
			};
		};
		if (!written) {
			sg_write_single(st.sink, buf);
			st.buffered = 0;
		};
	};
	return len(buf_orig);
};

// Securely write like sg_write without checking matches across multiple writes
fn sg_write_single(sink: io::handle, buf: []u8) void = {
	if (bytes::contains(buf, scriptbuf)) {
		let i = 0z; // number of bytes written
		for (i <= len(buf) - len(scriptbuf)) {
			if (bytes::equal(buf[i..i+len(scriptbuf)], scriptbuf)) {
				io::writeall(sink,
					strings::toutf8("<\\/script"))!;
				i += len(scriptbuf);
			} else {
				io::writeall(sink, buf[i..i+1])!;
				i += 1;
			};
		};
		io::writeall(sink, buf[i..])!;
	} else io::writeall(sink, buf)!;
};

fn sg_close(st: *io::stream) (void | io::error) = {
	const st = st: *sgstream;
	if (st.buffered != 0) io::writeall(st.sink, scriptbuf[..st.buffered])!;
};
