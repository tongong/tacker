use fmt;
use fs;
use getopt;
use io;
use os;
use strings;

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
	const ifile = resolve_path(ifile, defaultfrom);
	// has to be uncommented again when the bug is fixed
	// https://todo.sr.ht/~sircmpwn/hare/717
	// (because of fmt::fatalf)
	// defer free(ifile);

	let extstart = lastdotindex(ifile);
	if (extstart == -1)
		fmt::fatalf("file \"{}\" has broken filetype.", ifile);
	let ext = strings::fromutf8(strings::toutf8(ifile)[(extstart + 1)..]);

	switch (ext) {
	case "html" => tacker_html(ifile, ofile);
	case "js" =>   tacker_js(ifile, ofile);
	case "css" =>  tacker_css(ifile, ofile);
	case => fmt::fatalf("unknown filetype: \"{}\".", ifile);
	};
};
