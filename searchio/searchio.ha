use fmt;
use io;
use os;
use sort;
use strings;

// // reads until end is read and pipes all read bytes to ofile (end itself not)
// // returns true if end is reached, false on EOF
// fn read_until(ifile: io::handle, ofile: io::handle, end: str) bool = {
// 	let end = strings::toutf8(end);
// 	let currIndex = 0z; // the current index in the buffer to check
// 	for (true) {
// 		const buf: [1]u8 = [' '];
// 		if (io::read(ifile, buf) is io::EOF) return false;
// 		if (buf[0] == end[currIndex]) {
// 			currIndex += 1;
// 			if (currIndex == len(end)) return true;
// 		} else {
// 			if (currIndex != 0) {
// 				io::write(ofile, end[..currIndex])!;
// 				currIndex = 0;
// 			};
// 			io::write(ofile, buf)!;
// 		};
// 	};
// 	return false; // unreachable
// };

// sorted
export type pattern = []patternelem;
export type patternelem = struct {
	// if the first n bytes are identical to the first n bytes in the string
	// before they are set to 0
	data: []u8,
	// index into the string list before compile
	index: size,
};

fn patternelem_cmp(a: *void, b: *void) int = {
	// the end of one of the strings will never be reached because than it
	// would be a substring of the other string which make the other string
	// impossible to find
	const a: []u8 = (*(a: *patternelem)).data;
	const b: []u8 = (*(b: *patternelem)).data;
	for (let i = 0z; true; i += 1) {
		if (a[i] < b[i]) return -1;
		if (a[i] > b[i]) return 1;
	};
	return 0; // will never be reached
};

// has to be freed TODO custom function for free
export fn compile(s: []str) pattern = {
	let p: pattern = [];
	for (let i = 0z; i < len(s); i += 1) {
		append(p, patternelem {
			data = strings::toutf8(s[i]),
			index = i,
		});
	};
	sort::sort(p: []void, size(patternelem), &patternelem_cmp:
		*sort::cmpfunc);
	for (let i = len(p) - 1; i >= 1; i -= 1) {
		for (let j = 0z; j < len(p[i].data) && j < len(p[i-1].data);
				j += 1) {
			if (p[i].data[j] == p[i-1].data[j]) {
				p[i].data[j] = 0;
			} else break;
		};
	};
	// for (let i = 0z; i < len(p); i+= 1) {
	// 	fmt::print(p[i].index)!;
	// 	for (let j = 0z; j < len(p[i].data); j+= 1) {
	// 		fmt::print(" ")!;
	// 		fmt::print(p[i].data[j])!;
	// 	};
	// 	fmt::println()!;
	// };
	return p;
};

// reads until one of the end strings is read and pipes all read bytes to ofile
// (not the matched end itself)
// does not work if the end of one pattern is the start of another
// returns pattern index (index into string list before compile)
export fn search(ifile: io::handle, ofile: io::handle, end: pattern)
		(size | io::EOF) = {
	// element in pattern array that is currently being matched
	// -1 -> none of them
	let curr_elem = 0z;
	// index into the matched element that is checked next
	let curr_index = 0z;
	// if an element is matched to a certain point but then a byte is wrong
	// this byte is stored here to maybe start a new match
	let leftover: u8 = 0;
	for (true) {
		let buf: [1]u8 = [' '];
		if (leftover != 0) {
			buf[0] = leftover;
			leftover = 0;
		} else if (io::read(ifile, buf) is io::EOF) return io::EOF;
		const buf = buf[0];

		let nomatches = true;
		for (let i = curr_elem; i < len(end); i += 1) {
			const e = end[i].data;
			if (curr_index != 0 && i != curr_elem &&
				e[curr_index - 1] != 0) break;
			if (e[curr_index] != 0 && e[curr_index] > buf) break;
			if (buf == e[curr_index]) {
				curr_elem = i;
				curr_index += 1;
				nomatches = false;
				if (curr_index == len(end[curr_elem].data))
					return end[curr_elem].index;
				break;
			};
		};
		if (nomatches) {
			if (curr_index != 0) {
				for (let i = 0z; i < curr_index; i += 1) {
					let elem = curr_elem;
					for (end[elem].data[i] == 0) {
						elem -= 1;
					};
					io::write(ofile, [end[elem].data[i]])!;
				};
				curr_elem = 0;
				curr_index = 0;
				leftover = buf;
			} else {
				io::write(ofile, [buf])!;
			};
		};
	};
	return io::EOF; // unreachable
};