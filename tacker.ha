use encoding::utf8;
use fmt;
use fs;
use getopt;
use io;
use os;
use rt;
use slices;
use strings;
use types;

// Inverse of strings::runes().
// why is not something like this in the stdlib?
// why does insertinto take a slice of pointers and not a pointer to a slice?
fn runes_to_str(runes: []rune) str = {
	let buffer = alloc([], len(runes) * 4): []u8: *[*]u8;
	let index = 0z;
	for (let i = 0z; i < len(runes); i += 1) {
		const u = encoding::utf8::encoderune(runes[i]);
		rt::memcpy(&buffer[index], &u[0], len(u));
		index += len(u);
	};
	const s = types::string {
		data     = buffer,
		length   = index,
		capacity = len(runes) * 4,
	};
	return *(&s: *const str);
};

// Returns index of the last dot in the filename or -1 if the file contains no
// dot.
fn lastdotindex(filename: []rune) int = {
	let index = (len(filename) - 1): int;
	for (index >= 0 && filename[index] != '.') {
		if (filename[index] == '/') {
			index = -1;
			break;
		};
		index -= 1;
	};
	return index;
};

// Input is borrowed, return value has to be freed.
// test.js -> test.bundle.js
// test.dot.js -> test.dot.bundle.js
// no-ext -> no-ext.bundle
fn file_name_bundled(ifile: str) str = {
	let slc = strings::runes(ifile);
	defer free(slc);
	let lastdot = lastdotindex(slc);
	// files without extension get the .bundle at the end
	if (lastdot == -1) lastdot = len(slc): int;

	static let b: []rune = [];
	static let bptr: [7]*void = [&b: *void ...];
	if (len(b) == 0) {
		b = strings::runes(".bundle");
		for (let i = 0z; i < len(b); i += 1) {
			bptr[i] = &b[i];
		};
	};
	slices::insertinto(&slc: *[]void, size(rune), lastdot: size, bptr...);
	return runes_to_str(slc);
};

type filetype = enum {
	HTML,
	JS,
	CSS,
	BINARY,
	UNKNOWN,
};

// Bundles all from input linked file and echos the bundle to the output stream.
// ifile: resolved path
fn tacker_write(ifile: str, ofile: io::handle, ft: filetype) void = {
	// const data = match (os::open(ifile, fs::flags::RDONLY)) {
	// case let data: io::file =>
	// 	yield data: io::handle;
	// case let data: fs::error =>
	// 	fmt::fatalf("file \"{}\" does not exist.", ifile);
	// };
	if (ft == filetype::UNKNOWN) {
		let slc = strings::runes(ifile);
		defer free(slc);
		let extstart = lastdotindex(slc);
		if (extstart == -1)
			fmt::fatalf("file \"{}\" has broken filetype.", ifile);
		let ext = runes_to_str(slc[(extstart + 1)..]);
		defer free(ext);
		static const knownft = [
			("html", filetype::HTML),
			("js",   filetype::JS),
			("css",  filetype::CSS),
		];
		for (let i = 0z; i < len(knownft); i += 1) {
			if (knownft[i].0 == ext) ft = knownft[i].1;
		};
	};
	// TODO
	fmt::println(switch (ft) {
	case filetype::HTML =>    yield "html";
	case filetype::JS =>      yield "js";
	case filetype::CSS =>     yield "css";
	case filetype::BINARY =>  yield "bin";
	case filetype::UNKNOWN => yield "unknown";
	})!;
};

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

export fn main() void = {
	const cmd = getopt::parse(os::args,
		"simple web bundler",
		('f', "formats", "file formats to inline (comma seperated)"),
		('p', "basepath", "for resolving modules (defaults to cwd)"),
		"input-file",
		"[output-file]",
	);
	defer getopt::finish(&cmd);

	const alen = len(cmd.args);
	if (alen == 0)
		fmt::fatal("at least the input file is as argument needed.");
	if (alen > 2) fmt::fatal("too many arguments passed.");

	basepath = strings::join("", os::getcwd(), "/");
	for (let i = 0z; i < len(cmd.opts); i += 1) {
		if (cmd.opts[i].0 == 'p') {
			free(basepath);
			basepath = strings::join("",
				realpath_resolve(cmd.opts[i].1), "/");
			if (basepath == "//") basepath = strings::fromutf8(strings::toutf8(basepath)[..1]);
		};
	};

	const ifile = cmd.args[0];
	const ofile = if (alen == 1) file_name_bundled(ifile)
	else strings::dup(cmd.args[1]);
	defer free(ofile);

	const ofile = if (ofile == "-") os::stdout
	else os::create(ofile, fs::mode::USER_RW | fs::mode::GROUP_R |
		fs::mode::OTHER_R, fs::flags::WRONLY, fs::flags::TRUNC)!
		: io::handle;
	defer io::close(ofile)!;

	const ifile = strings::join("", "./", ifile);
	defer free(ifile);
	const defaultfrom = strings::join("", os::getcwd(), "/");
	defer free(defaultfrom);
	tacker_write(resolve_path(ifile, defaultfrom), ofile,
		filetype::UNKNOWN);
};
