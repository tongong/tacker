use bufio;
use fmt;
use io;
use os;
use searchio;
use strings;

// https://html.spec.whatwg.org/multipage/syntax.html

// inputs are borrowed
fn tacker_html(inputpath: str, ofile: io::handle) void = {
	const ifile = os::open(inputpath)!;
	defer io::close(ifile)!;
	const p_main = searchio::compile(["<!--", "<script", "<link",
		"<audio", "<embed", "<img", "<source", "<track", "<video"]);
	const p_comment = searchio::compile(["-->"]);
	const p_tagclose = searchio::compile([">"]);
	const p_scriptclose = searchio::compile(["</script>"]);
	defer searchio::finish(p_main);
	defer searchio::finish(p_comment);
	defer searchio::finish(p_tagclose);
	defer searchio::finish(p_scriptclose);

	for (true) {
		const m = searchio::search(ifile, ofile, p_main);
		if (m is size) {
			const m = m: size;

			let tagbuf = bufio::dynamic(io::mode::RDWR);
			defer io::close(&tagbuf)!;
			if (m != 0) {
				fmt::fprint(&tagbuf, p_main.original[m])!;
				searchio::search(ifile, &tagbuf, p_tagclose);
				fmt::fprint(&tagbuf, ">")!;
			};

			if (m == 0) {
				// html comments
				fmt::fprint(ofile, "<!--")!;
				searchio::search(ifile, ofile, p_comment);
				fmt::fprint(ofile, "-->")!;
			} else if (m == 1) {
				// <script> -> look at src and replace the whole
				// tag
				const src = tag_get_attr(tagbuf.buf,
					strings::toutf8("src"));
				if (src is not_found) {
					io::writeall(ofile, tagbuf.buf)!;
				} else {
					searchio::search(ifile, black_hole,
						p_scriptclose);
					const src = src: tag_split;
					const src = strings::fromutf8(src.1);
					fmt::fprint(ofile, "<script>\n")!;
					const src = resolve_path(src,
						inputpath);
					defer free(src);
					tacker_js(src, ofile, true);
					fmt::fprint(ofile, "</script>")!;
				};
			} else if (m == 2) {
				// stylesheets -> look at rel and href and
				// replace the whole tag
				const rel = tag_get_attr(tagbuf.buf,
					strings::toutf8("rel"));
				let is_style = rel is tag_split;
				const rel = if (is_style) {
					const rel = rel: tag_split;
					const rel = strings::fromutf8(rel.1);
					if (rel != "stylesheet")
						is_style = false;
					yield rel;
				} else "";
				if (!is_style) {
					io::writeall(ofile, tagbuf.buf)!;
				} else {
					const href = tag_get_attr(tagbuf.buf,
						strings::toutf8("href"));
					if (href is not_found)
						fixed_fatalf("{}: broken style tag \"{}\".",
							inputpath,
							strings::fromutf8(
							tagbuf.buf));
					const href = href: tag_split;
					const href = strings::fromutf8(href.1);
					fmt::fprint(ofile, "<style>\n")!;
					const href = resolve_path(href,
						inputpath);
					defer free(href);
					tacker_css(href, ofile);
					fmt::fprint(ofile, "</style>")!;
				};
			} else {
				// media tags -> look at src and replace only
				// src, not the whole tag
				const src = tag_get_attr(tagbuf.buf,
					strings::toutf8("src"));
				if (src is not_found) {
					io::writeall(ofile, tagbuf.buf)!;
				} else {
					const src = src: tag_split;
					const srctext = strings::fromutf8(
						src.1);
					const srctext = resolve_path(srctext,
						inputpath);
					defer free(srctext);
					io::writeall(ofile, src.0)!;
					fmt::fprint(ofile, "data:;base64,")!;
					tacker_binary(srctext, ofile);
					io::writeall(ofile, src.2)!;
				};
			};
		} else break;
	};
};


// Search an attribute inside an html tag.
// Return the input buffer split at the borders of the value of the found
// attribute.
type not_found = void;
type tag_split = ([]u8, []u8, []u8);
type quotes = enum {
	NORMAL,
	SINGLE,
	DOUBLE
};
fn tag_get_attr(tag: []u8, attr: []u8) (tag_split | not_found) = {
	// STRATEGY
	// go through the string and find all '=' that are not inside quotes
	// find the corresponding attribute name and if it is fitting find the
	// corresponding value
	let state = quotes::NORMAL;
	for (let i = 0z; i < len(tag); i += 1) {
		switch (state) {
		case quotes::NORMAL => {
			if (tag[i] == '"') state = quotes::DOUBLE;
			if (tag[i] == '\'') state = quotes::SINGLE;
			if (tag[i] == '=') {
				const pos_equal = i;
				let pos_endattr = pos_equal - 1;
				for (isspace(tag[pos_endattr]))
					pos_endattr -= 1;
				pos_endattr += 1;
				let pos_startattr = pos_endattr - 1;
				for (!isspace(tag[pos_startattr]))
					pos_startattr -= 1;
				pos_startattr += 1;
				const amatch = tag[pos_startattr..pos_endattr];
				if (cmpcase(attr, amatch)) {
					let pos_startval = pos_equal + 1;
					for (isspace(tag[pos_startval]))
						pos_startval += 1;
					let pos_endval = pos_startval;
					if (tag[pos_startval] == '\'') {
						pos_startval += 1;
						pos_endval += 1;
						for (tag[pos_endval] != '\'')
							pos_endval += 1;
					} else if (tag[pos_startval] == '"') {
						pos_startval += 1;
						pos_endval += 1;
						for (tag[pos_endval] != '"')
							pos_endval += 1;
					} else {
						for (!isspace(tag[pos_endval]))
							pos_endval += 1;
					};
					return (tag[..pos_startval],
						tag[pos_startval..pos_endval],
						tag[pos_endval..]);
				};
			};
		};
		case quotes::SINGLE => {
			if (tag[i] == '\'') state = quotes::NORMAL;
		};
		case quotes::DOUBLE => {
			if (tag[i] == '"') state = quotes::NORMAL;
		};
		};
	};
	return not_found;
};


@test fn tag_get_attr() void = {
	const t = strings::toutf8("<script attr1 attr2 = test attr3= 'asdasdf = \"asdfasdf' sRc=\"filename\">");
	const a = strings::toutf8("src");
	const res = tag_get_attr(t, a);
	assert(res is tag_split);
	const res = res: tag_split;
	assert(strings::fromutf8(res.0) == "<script attr1 attr2 = test attr3= 'asdasdf = \"asdfasdf' sRc=\"");
	assert(strings::fromutf8(res.1) == "filename");
	assert(strings::fromutf8(res.2) == "\">");
};


// There are similar functions in the ascii module but there is no utf8 in
// html attributes so this is sufficient.
fn isspace(c: u8) bool =
	c == ' ' || c == '\t' || c == '\n' || c == '\f' || c == '\r';


fn tolower(c: u8) u8 = {
	if ('A' <= c && c <= 'Z') return c - 'A' + 'a';
	return c;
};


// Return true if the two buffers are case-insensitively equal
fn cmpcase(a: []u8, b: []u8) bool = {
	if (len(a) != len(b)) return false;
	for (let i = 0z; i < len(a); i += 1) {
		if (tolower(a[i]) != tolower(b[i])) return false;
	};
	return true;
};
