use encoding::utf8;
use fmt;
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
