use fs;
use io;
use os;
use slices;
use strings;

// All bundled files must be within this directory so that malicious modules
// cannot require arbitrary files on the file system.
let basepath: str = "";
@fini fn fini() void = free(basepath);

// Cut a string to the last "/".
// Return value is borrowed from the input.
fn parent_dir(path: str) str = {
	const bytes = strings::toutf8(path);
	let i = len(bytes) - 1;
	for (bytes[i] != '/') i -= 1;
	return strings::fromutf8(bytes[..(i+1)]);
};

// Apply os::realpath and os::resolve.
fn realpath_resolve(path: str) str = {
	const p = match (os::realpath(path)) {
	case let p: str => yield p;
	case let p: fs::error =>
		fixed_fatalf("{}: file does not exist.", path);
		yield ""; // unreachable
	};
	return os::resolve(p);
};

// path: to be resolved
// from: path to the file (or directory) where the reference was found.
// Return value has to be freed.
fn resolve_path(path: str, from: str) str = {
	if (strings::hasprefix(path, "http://") ||
			strings::hasprefix(path, "https://")) {
		fixed_fatalf("{}: bundling of external resources is not allowed.",
			path);
	};
	// directory path is relativ to base
	// ends with "/"
	const base = if (strings::hasprefix(path, "./") ||
			strings::hasprefix(path, "../")) {
		yield parent_dir(from);
	} else {
		yield basepath;
	};
	const r = strings::join("", base, path);
	defer free(r);
	const r = strings::dup(realpath_resolve(r));
	if (!strings::hasprefix(r, basepath))
		fixed_fatalf("{}: file path violates the base path \"{}\".",
			r, basepath);
	return r;
};

// Works like resolve_path() but adds a .js extension if there is none
fn resolve_path_require(path: str, from: str) str = {
	return if (strings::hassuffix(path, ".js"))
		resolve_path(path, from)
	else {
		const p = strings::join("", path, ".js");
		const res = resolve_path(p, from);
		free(p);
		yield res;
	};
};

// Return index of the last dot in the filename or -1 if the file contains no
// dot.
fn lastdotindex(filename: str) int = {
	const filename = strings::toutf8(filename);
	let index = (len(filename) - 1): int;
	for (index >= 0 && filename[index] != '.') {
		if (filename[index] == '/') return -1;
		index -= 1;
	};
	return index;
};

// return value has to be freed.
fn file_name_bundled(filename: str) str = {
	let lastdot = lastdotindex(filename);
	// files without extension get the .bundle at the end
	if (lastdot == -1) lastdot = len(filename): int;

	const output = strings::dup(filename);
	const output = strings::toutf8(output);

	const ext = strings::toutf8(".bundle");
	let bptr: [7]*void = [&ext: *void ...];
	for (let i = 0z; i < len(ext); i += 1) {
		bptr[i] = &ext[i];
	};
	slices::insertinto(&output: *[]void, size(u8), lastdot: size, bptr...);
	return strings::fromutf8(output);
};

@test fn file_name_bundled() void = {
	assert(file_name_bundled("test.js") == "test.bundle.js");
	assert(file_name_bundled("test.dot.js") == "test.dot.bundle.js");
	assert(file_name_bundled("no-ext") == "no-ext.bundle");
	assert(file_name_bundled("./dir.a/no-ext") == "./dir.a/no-ext.bundle");
	assert(file_name_bundled("./test.dir/ütf8.html") ==
		"./test.dir/ütf8.bundle.html");
};

// A file to write useless output to (like /dev/null)
const black_hole: io::handle = &black_hole_s;
const black_hole_s: io::stream = &black_hole_v;
const black_hole_v: io::vtable = io::vtable {
	reader = null,
	writer = &black_hole_write,
	...
};
fn black_hole_write(s: *io::stream, buf: const []u8) (size | io::error) = {
	return len(buf);
};
