use encoding::base64;
use io;
use os;

fn tacker_binary(ifile: str, ofile: io::handle) void = {
	const enc = base64::newencoder(&base64::url_encoding, ofile);
	const ifile = os::open(ifile)!;
	defer io::close(ifile)!;
	io::copy(&enc, ifile)!;
	io::close(&enc)!;
};
