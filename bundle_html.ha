use fmt;
use io;
use os;
use searchio;

// inputs are borrowed
fn tacker_html(ifile: str, ofile: io::handle) void = {
	const ifile = os::open(ifile)!;
	const p = searchio::compile([">", "<head", "<body", "<script", "test", "src"]);
	for (true) {
		if (searchio::search(ifile, ofile, p) is size) {
			fmt::print("[replaced]")!;
		} else break;
	};
};
