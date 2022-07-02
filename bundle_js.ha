use fmt;
use io;
use os;

// html: true if the output can be inlined in a html script tag. This is
//       important because code like e.g.
//           let tag = "</script>";
//       has to be escaped.
fn tacker_js(inputpath: str, ofile: io::handle, html: bool) void = {
	const ifile = os::open(inputpath)!;
	defer io::close(ifile)!;
	// TODO
	for (true) {
		let buf: [1]u8 = [' '];
		if (io::read(ifile, buf) is io::EOF) return;
		io::write(ofile, buf)!;
	};
};
