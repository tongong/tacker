use encoding::hex;
use encoding::utf8;
use fmt;
use getopt;
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

// Input is borrowed, return value has to be freed.
// test.js -> test.bundle.js
// test.dot.js -> test.dot.bundle.js
// no-ext -> no-ext.bundle
fn file_name_bundled(ifile: str) str = {
	let slc = strings::runes(ifile);
	defer free(slc);
	let lastdot = (len(slc) - 1): int;
	for (lastdot >= 0 && slc[lastdot] != '.') {
		if (slc[lastdot] == '/') {
			lastdot = -1;
			break;
		};
		lastdot -= 1;
	};
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

export fn main() void = {
	const cmd = getopt::parse(os::args,
		"simple web bundler",
		('f', "formats", "file formats to inline (comma seperated)"),
		"input-file",
		"output-file",
	);
	defer getopt::finish(&cmd);

	const alen = len(cmd.args);
	if (alen == 0)
		fmt::fatal("At least the input file is as argument needed.");
	if (alen > 2) fmt::fatal("Too many arguments passed.");
	const ifile = cmd.args[0];
	const ofile = if (alen == 1) {
		// generate output file name from input file name
		yield file_name_bundled(ifile);
	} else {
		yield strings::dup(cmd.args[1]);
	};
	defer free(ofile);

	fmt::println(ifile)!;
	fmt::println(ofile)!;
};
