use fmt;
use fs;
use getopt;
use io;
use os;
use strings;

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
			if (basepath == "//") basepath = strings::fromutf8(
				strings::toutf8(basepath)[..1]);
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
