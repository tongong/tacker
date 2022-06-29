use encoding::base64;
use io;
use os;

fn tacker_binary(inputpath: str, ofile: io::handle) void = {
	const ifile = os::open(inputpath)!;
	defer io::close(ifile)!;
	const enc = base64::newencoder(&base64::std_encoding, ofile);
	io::copy(&enc, ifile)!;
	io::close(&enc)!;
};
