use fmt;
use fs;
use os;
use strings;

// All bundled files must be within this directory so that malicious modules
// cannot require arbitrary files on the file system.
let basepath: str = "";
@fini fn fini() void = free(basepath);

// Cuts a string to the last "/".
// Return value is borrowed from the input.
fn parent_dir(path: str) str = {
	const bytes = strings::toutf8(path);
	let i = len(bytes) - 1;
	for (bytes[i] != '/') i -= 1;
	return strings::fromutf8(bytes[..(i+1)]);
};

// Applys os::realpath and os::resolve.
fn realpath_resolve(path: str) str = {
	const p = match (os::realpath(path)) {
	case let p: str => yield p;
	case let p: fs::error =>
		fmt::fatalf("path \"{}\" does not exist.", path);
	};
	return os::resolve(p);
};

// path: to be resolved
// from: path to the file (or directory) where the reference was found.
// Return value has to be freed.
fn resolve_path(path: str, from: str) str = {
	// directory path is relativ to
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
		fmt::fatalf("file path \"{}\" violates the base path \"{}\".",
			r, basepath);
	return r;
};
