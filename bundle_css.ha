use fmt;
use io;
use os;

fn tacker_css(inputpath: str, ofile: io::handle) void = {
	const ifile = os::open(inputpath)!;
	defer io::close(ifile)!;
	// TODO
	for (true) {
		let buf: [1]u8 = [' '];
		if (io::read(ifile, buf) is io::EOF) return;
		io::writeall(ofile, buf)!;
	};
};
