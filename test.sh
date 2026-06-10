#!/usr/bin/env bash

# Cleanup on CTRL-C
tmpdir='dir_with_unpacked_files'
trap 'if [[ -n "$tmpdir" ]]; then rm -rf "$tmpdir"; echo; exit 1; fi' SIGINT

usage() {
	cat <<EOF
Usage: $0 [-h] [-n] [-v] [number[s]] [string[s]] [file_name]
  Test lesspipe.sh against a number of files and report failures
  -h        This help message
  -v        Print the output of all commands and the test string
  -n        Test commands are printed only, not checked
            With -v print also required auxiliary programs in parentheses
  -c        color tests only, override colorizer used,
            take it from LESSCOLORIZER, or try to find a suitable one
  file_name The script to test against in the current directory [lesspipe.sh]
  The number[s] and string[s] arguments can be used to limit the tests to be
  performed. Number ranges are allowed. Strings can be part of the command
  or the comment attached to the test commands.
  The test commands and test strings are stored in this program.
  The '= some string' means, that 'some string' including a newline char
  must be the test result. The '~ match string' means, that 'match string'
  must match a complete line in the output, the 'c string' must match string
  surrounded with Escape sequences. In the latter case a successful test
  is usually displayed with a colored 'ok'
EOF
	exit 0
}

# Check if a program is executable
# Special handling for cpio to ensure GNU version
is_exec() {
	local arg="$1" cmdpath

	[[ -z $arg ]] && return 0

	if [[ $arg == cpio && $(cpio --version 2>/dev/null) != *GNU* ]]; then
		return 1
	fi

	cmdpath=$(command -v "$arg")
	[[ -n $cmdpath && -x $cmdpath ]]
}

# Remove ANSI escape sequences and empty lines
remove_ansi() {
	local text="$1"
	echo "$text" | sed -E 's/\x1b\[[0-9;]*m//g; /^$/d'
}

# Compare test result with expected output
# Supports three comparison types: c (colored), ~ (regex), = (exact)
compare() {
	local ok='ok'
	local res="$1" type="$comp"
	local comp="${comp:2:${#comp}}"

	# Handle colored output (c)
	if [[ ${type:0:1} == c ]]; then
		if echo "$res"|grep -qE '[[0-9;]+m'; then
			res=$(echo "$res" | grep -E "$comp" 2>/dev/null)
			local str="${res%"$comp"*}ok"
			str=$(echo "$str" | sed -E 's/^.*(\x1b\[[0-9;]+m) ?ok/\1ok/g')
			res="$str[0m"
			# special case test 105
			ok=${res//-/}
		else
			ok=
		fi
	fi

	# Remove ANSI sequences and empty lines
	res=$(remove_ansi "$res")

	# Handle regex match (~ type)
	if [[ ${type:0:1} == \~ ]]; then
		res=$(echo "$res"|sed 's/.//g;s///g;')
		nok=$(echo "$res"|grep -qE "$comp")
		[[ -n "$nok" ]] && ok=
	# # Handle exact match (= type)
	elif [[ ${type:0:1} == = ]]; then
		# Remove various BOM markers
		res=${res//$'\UFEFF'/}
		res=${res//$'\UEFBBBF'/}
		res=${res//$'\UBBBF'/}
		[[ "$comp" != "$res" ]] && ok=
	fi

	echo "$ok"
}

seconds=$(date +%s)

# Parse command-line arguments
fname="lesspipe.sh"
declare -a numtest strtest
args="$*" args=${args//,/ }

while [[ "$args" != "$arg" ]]; do
	arg=${args%% *}
	args=${args#"$arg" }
	if [[ $arg =~ ^-([chnv]+)$ ]]; then
		[[ $arg =~ h ]] && usage
		[[ $arg =~ v ]] && verbose=1
		[[ $arg =~ n ]] && noaction=1
		[[ $arg =~ c ]] && force_colorizer=1
	elif [[ $arg =~ ^[0-9]*-[0-9]+$ ]]; then
		start=${arg%-*} end=${arg#*-}
		((start)) || start=1
		for ((i=start; i<=end; i++)); do numtest+=("$i"); done
	elif [[ $arg =~ ^[0-9]+-$ ]]; then
		start=${arg%-*} end=199
		((start)) || start=1
		for ((i=start; i<=end; i++)); do numtest+=("$i"); done
	elif [[ $arg =~ ^[0-9]+$ ]]; then
		numtest+=("$arg")
	elif [[ -r $arg ]]; then
		fname="$arg"
	elif [[ $arg =~ ^[a-zA-Z0-9/:] ]]; then
		strtest+=("$arg")
	else
		usage
	fi
done

# Set up environment
dir="${0%/*}/"
[[ $fname != */* ]] && fname="./$fname"

export LESSOPEN="|-$fname %s"
echo "testing $fname" && echo "LESSOPEN=\"$LESSOPEN\""
export LESS='-R'
export LESSQUIET=1
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'
export TZ=''
colorizers=(nvimpager batcat bat pygmentize source-highlight vimcolor code2color e2ansi-cat)

sumok=0 sumignore=0 sumnok=0 num=0 colors=0

errmsg=
if [[ -z $noaction ]]; then
	[[ $TERM == *256* ]] && colors=256
	command -v tput &>/dev/null && colors=$(tput colors)
	if ! is_exec "$LESSCOLORIZER" ; then
		errmsg=" $LESSCOLORIZER not available,"
		unset LESSCOLORIZER
	fi
	if [[ "$colors" -ge 8 && -z "$LESSCOLORIZER" && -n "$force_colorizer" ]]; then
		for i in "${colorizers[@]}" ; do
			is_exec "$i" && export LESSCOLORIZER="$i" && break
		done
	fi
	[[ -n "$force_colorizer" ]] && echo "Use $LESSCOLORIZER as colorizer,$errmsg usually not all tests will succeed"

	# Temp dir setup
	tmpdir=$(mktemp -d --tmpdir "lesspipe.XXXXXX") || {
		echo "Failed to create temp directory"
		exit 1
	}
	mkdir -p "$tmpdir/tests"
	T="$tmpdir/tests"

	# Copy test archives (validate they exist)
	for ar in archive compress filter special; do
		if [[ ! -f "tests/${ar}.tgz" ]]; then
			echo "Error: Missing tests/${ar}.tgz"
			rm -rf "$tmpdir"
			exit 1
		fi
		cp "tests/${ar}.tgz" "$T/" || {
			echo "Error: Failed to copy tests/${ar}.tgz"
			rm -rf "$tmpdir"
			exit 1
		}
	done

	cwd="$PWD"
	cd "$T" || {
		echo "Error: Failed to cd to $T"
		rm -rf "$tmpdir"
		exit 1
	}

	# Extract archives
	for ar in archive compress filter special; do
		tar -xzf "${ar}.tgz" || echo "Extraction failed for $ar"
	done
	ln -s test_plain symlink
	cd "$cwd" || {
		echo "Error: Failed to cd back to $cwd"
		rm -rf "$tmpdir"
		exit 1
	}
fi

# prefer lesspipe.sh in current directory
export PATH="$dir:$PATH"
# Verify lesspipe.sh exists and is executable
if [[ ! -x "$fname" ]]; then
	echo "Error: Cannot execute $fname"
	exit 1
fi

# Test data
read -r -d '' tests << 'EOF'
### archive tests
1 less tests/archive.tgz:			# contents of archive with test files
~ .* test_cab
2 less $T/tests/test_tar			# tar contents (from unpacked file)
~ .* tests/textfile
3 less tests/archive.tgz:test_tar		# tar contents (from archive without unpacking)
~ .* tests/textfile
4 less $T/tests/test_tar:tests/textfile	# extract file from tar (unpacked)
= test
5 less tests/archive.tgz:test_tar:tests/textfile # (on the fly)
= test
### plain tar file names with a : not allowed, use ./tar:name, not tar:name
6 less $T/tests/test:tar			# tar file name with colon git #51
~ .* tests/textfile
7 less $T/tests/test:tar=tests/textfile	# extract file from tar file with colon
= test
8 less $T/tests/test_rpm			# rpm contents, needs rpm2cpio
~ .* ./textfile
9 less tests/archive.tgz:test_rpm		# (on the fly), needs rpm2cpio
~ .* ./textfile
10 less $T/tests/test_rpm:./textfile		# extract file from rpm, needs rpm2cpio
= test
11 less tests/archive.tgz:test_rpm:./textfile	# (on the fly), needs rpm2cpio
= test
12 less $T/tests/test.jar			# jar contents, needs unzip
~ .*/MANIFEST.MF
13 less tests/archive.tgz:test.jar		# (on the fly), needs unzip
~ .*/MANIFEST.MF
14 less $T/tests/test.jar:META-INF/MANIFEST.MF	# # extract file from jar, needs unzip
~ .*: test
15 less tests/archive.tgz:test.jar:META-INF/MANIFEST.MF	# (on the fly), needs unzip
~ .*: test
16 less $T/tests/test_zip			# zip contents, needs unzip
~ .* 10240 .*
17 less tests/archive.tgz:test_zip		# (on the fly), needs unzip
~ .* 10240 .*
18 less $T/tests/test_zip:tests/test.tar	# extract tar archive from zip, needs unzip
~ .* tests/textfile
19 less tests/archive.tgz:test_zip:tests/test.tar	# (on the fly), needs unzip
~ .* tests/textfile
20 less $T/tests/test_zip:tests/test.tar:tests/textfile	# extract file from chained archives git #45, needs unzip
= test
21 less tests/archive.tgz:test_zip:tests/test.tar:tests/textfile	# (on the fly), needs unzip
= test
22 less $T/tests/test_deb					# debian contents, needs ar|bsdtar
~ .* ./test.txt
23 less tests/archive.tgz:test_deb		# (on the fly), needs ar|bsdtar
~ .* ./test.txt
24 less $T/tests/test_deb:./test.txt		# extract file from debian package, needs ar|bsdtar
= test
25 less tests/archive.tgz:test_deb:./test.txt	# (on the fly), needs ar|bsdtar
= test
26 less $T/tests/test_rar			# rar contents, needs unrar|rar|bsdtar
~ .* testok/a b
27 less tests/archive.tgz:test_rar		# (on the fly), needs unrar|rar|bsdtar
~ .* testok/a b
28 less $T/tests/test_rar:testok/a\ b		# extract file from rar, needs unrar|rar|bsdtar
= test
29 less tests/archive.tgz:test_rar:testok/a\ b	# (on the fly), needs unrar|rar|bsdtar
= test
30 less $T/tests/test_cab			# ms cabinet contents, needs cabextract
~ .* cabinet.txt
31 less tests/archive.tgz:test_cab		# (on the fly), needs cabextract
~ .* cabinet.txt
32 less $T/tests/test_cab:a\ text.gz		# extract gzipped file from cab, needs cabextract
= test
33 less tests/archive.tgz:test_cab:a\ text.gz	# (on the fly), needs cabextract
= test
34 less $T/tests/test_7z			# 7z contents, needs 7zz|7zr|7za
~ .* testok/aaa.txt
35 less tests/archive.tgz:test_7z		# (on the fly), needs 7zz|7zr|7za
~ .* testok/aaa.txt
36 less $T/tests/test_7z:testok/a\|b.txt	# extract file from 7z, needs 7zz|7zr|7za
= test
37 less tests/archive.tgz:test_7z:testok/a\|b.txt	# (on the fly), needs 7zz|7zr|7za
= test
38 less $T/tests/test_iso			# iso9660 contents, needs bsdtar|isoinfo
~ .* ISO.TXT|/ISO.TXT;1
39 less tests/archive.tgz:test_iso		# (on the fly), needs bsdtar|isoinfo
~ .* ISO.TXT|/ISO.TXT;1
40 less $T/tests/test_iso:ISO.TXT		# extract file from iso9660, needs bsdtar
= test
41 less tests/archive.tgz:test_iso:ISO.TXT	# (on the fly), needs bsdtar
= test
42 less $T/tests/test_iso:/ISO.TXT\;1		# extract file from iso9660, needs isoinfo,!bsdtar
= test
43 less tests/archive.tgz:test_iso:/ISO.TXT\;1	# (on the fly), needs isoinfo,!bsdtar
= test
44 less $T/tests/test_ar			# ar archive contents, needs ar
~ .* a=b/?
45 less tests/archive.tgz:test_ar		# (on the fly), needs ar
~ .* a=b/?
46 less $T/tests/test_ar:a=b			# extract file from ar, needs ar
= test
47 less tests/archive.tgz:test_ar:a=b	# (on the fly), needs ar
= test
48 less $T/tests/test_cpio:textfile	# extract from cpio, needs cpio
= test
49 less tests/archive.tgz:test_cpio:textfile	# (on the fly), needs cpio
= test
### uncompress tests not covered in archive tests
50 less tests/compress.tgz:test.tar.bz2:tests/textfile	# extract from bzip2, needs bzip2
= test
51 less tests/compress.tgz:test.tar.lzip:tests/textfile	# extract from lzip, needs lzip
= test
52 less tests/compress.tgz:test.tar.lzma:tests/textfile	# extract from lzma, needs lzma
= test
53 less tests/compress.tgz:test.tar.xz:tests/textfile	# extract from xz, needs xz
= test
# do not call dd for brotli files git #19 (revert git #16)
54 less tests/compress.tgz:test.bro:tests/textfile		# extract from brotli, needs brotli
= test
55 less tests/compress.tgz:test.tar.zst:tests/textfile	# extract from zstandard git #13,20,36,44, needs zstd
= test
56 less tests/compress.tgz:test.tar.lz4:tests/textfile	# extract from lz4 git #14, needs lz4
= test
### filter tests, produce readable output
57 less tests/filter.tgz:test_utf16	# UTF-16 Unicode, needs iconv,locale
~ test
58 less tests/filter.tgz:test_latin1	# ISO-8859-1 encoded file, needs iconv,locale
= testäöü
### no output if file not modified (watch growing files) git #4,25 (revert)
59 less $T/tests/test_plain			# plain text, no output from lesspipe.sh
= test=a
60 less tests/filter.tgz:test_html		# html text, needs html_converter
~ \s*test
61 less tests/filter.tgz:test_html::	# html unmodified text
~ </head>
62 less tests/filter.tgz:test_pdf		# pdf, needs pdfinfo|pdftotext|pdftohtml,html_converter
~ \s*test
63 less tests/filter.tgz:test_ps		# postscript, needs ps2ascii
~ .*test\ ?1?$
64 less tests/filter.tgz:test.class	# java class file, needs procyon
c public class test
65 less tests/filter.tgz:test_docx		# docx (neu) git #24,26,27,37, needs pandoc|docx2txt|libreoffice
= test
66 less tests/filter.tgz:test_pptx		# pptx (neu), needs pptx2md,pandoc|libreoffice,html_converter
~ processing slide 1...|.*test.*
67 less tests/filter.tgz:test_xlsx		# xlsx (neu), needs in2csv|xlscat|excel2csv|libreoffice
~ ^test$
68 less tests/filter.tgz:test_odt		# odt, needs pandoc|odt2txt|libreoffice
= test
69 less tests/filter.tgz:test_odp		# odp, needs libreoffice,html_converter
~ \s*test
70 less tests/filter.tgz:test_ods		# ods, needs xlscat|libreoffice,html_converter
~ test
71 less tests/filter.tgz:test_doc		# doc (old), needs wvText|catdoc|libreoffice
~ test
72 less tests/filter.tgz:test_ppt:ms-powerpoint	# ppt (old), catppt not always working, needs libreoffice,html_converter
~ .*1. test|\s*test
73 less tests/filter.tgz:test_xls		# xls (old), needs in2csv|xls2csv|libreoffice,html_converter
~ ^test\ ?$|^"test"\ ?$
74 less tests/filter.tgz:test_ooffice1	# openoffice1 (very old), needs odt2txt
= test
75 less tests/filter.tgz:test_nroff	# man pages etc (nroff), needs groff|mandoc
~ .* Commands
76 less tests/filter.tgz:test_rtf		# rtf, needs unrtf|libreoffice
~ test
77 less tests/filter.tgz:test_dvi		# dvi, needs dvi2tty
~ test
78 less tests/filter.tgz:test_so		# shared library (.so), needs nm
~ .* T test
79 less tests/filter.tgz:test_pod		# pod text, needs pod2text|perldoc
~ ^NAME
80 less tests/filter.tgz:test.pod:		# unmodified pod text, needs pod2text|perldoc
~ test
81 less tests/filter.tgz:test_nc4		# netcdf, needs h5dump|ncdump
~ data:|\s*DATA .
82 less tests/filter.tgz:test_nc5		# hierarchical data format, needs h5dump|ncdump
~ data:|\s*DATA .
83 less tests/filter.tgz:test_matlab	# matlab git #18, needs matdump
~ r
84 less tests/filter.tgz:matlab.mat	# matlab, not recognized by file, needs matdump
~ r
85 less tests/filter.tgz:test_djvu		# djvu, needs djvutxt
~ ^test\ ?$
86 less tests/filter.tgz:test.pem		# SSL related files git #15, needs openssl
~ .* 2038 GMT
87 less tests/filter.tgz:test.bplist	# Apple binary property list, needs plistutil
~ <dict>
### no test case for decoding gpg/pgp encrypted files git #12
88 less tests/filter.tgz:test_mp3		# mp3 without mp3 extension, needs ffprobe|mediainfo|exiftool
~ [Tt]itle *: *test
89 less tests/filter.tgz:test_mp3:mp3	# mp3, needs ffprobe|eyeD3|id3v2
~ [Tt]itle *: *test
90 less tests/filter.tgz:test_data		# binary data
= test
### colorizing tests (ok should be displayed colored, for MacOSX see git #48)
91 less $T/tests				# directory, needs archive_color
c test_so
92 less tests/archive.tgz			# contents of tar colorized, needs archive_color
c test_cab
93 LESSCOLORIZER=source-highlight less tests/filter.tgz:test.c	# C language git #3, needs source-highlight
c void
94 LESSCOLORIZER=batcat less tests/filter.tgz:test.c		# C language from file within archive, needs batcat
c void
95 LESSCOLORIZER=bat less tests/filter.tgz:test.c		# C language from file within archive, needs bat,!batcat
c void
96 LESSCOLORIZER='pygmentize -O style=vim' less tests/filter.tgz:test.c # allow setting pygmentize style option git #5, needs pygmentize
c void
97 cat $T/tests/test.c|LESSCOLORIZER=pygmentize less - :c		# even colorize piped files, needs pygmentize
c void
98 LESSCOLORIZER=nvimpager less tests/filter.tgz:test_html:html	# html colorized text, needs nvimpager
c "created"
99 LESSCOLORIZER=vimcolor less tests/filter.tgz:test_pod:pod	# unmodified pod text, colorized, needs pod2text,vimcolor
c NAME
100 LESSCOLORIZER=pygmentize less tests/filter.tgz:test_plain:sh	# plain text, force colored shellscript, needs pygmentize
c test
101 LESSCOLORIZER=nvimpager less tests/filter.tgz:index.rst		# reStructuredText, needs pandoc,nvimpager
c test.png
102 LESSCOLORIZER=vimcolor less tests/filter.tgz:test.json		# json, epub and ipynb also covered git #62 (requires syntax/json.vim), needs vimcolor,pandoc
c "hello"
103 LESSCOLORIZER=source-highlight less tests/filter.tgz:t.eclass		# ebuild and eclass file git #9,38,39, needs source-highlight
c test
104 LESSCOLORIZER=e2ansi-cat less tests/filter.tgz:Makefile		# bsd Makefile not recognized with file 5.28 / with 5.39 o.k. git #10, needs e2ansi-cat
c PORTNAME
105 diff -u $T/tests/t.eclass $T/tests/test.c|LESSCOLORIZER=vimcolor less - :diff # unified diff piped through less works git #11, needs vimcolor
c test=a
106 LESSCOLORIZER=code2color less tests/special.tgz:a-r-R.pl	# colorize works within archives, needs code2color
c test
107 LESSCOLORIZER=vimcolor less $T/tests/special.tgz:.gitconfig	# colorize known dotfiles git #154, needs vimcolor
c name
108 LESSCOLORIZER=vimcolor less $T/tests/special.tgz:a-r-R.pl	# do not call vimcolor with -l extension git #77, needs vimcolor
c test
### solved github issues and other test cases
109 less tests/filter.tgz:test_dtb	# device tree blob, needs dtc
~ model = "test"
110 LESS= less $T/tests/a-r-R.pl		# name contains -r or -R git #78
= sub test {}
111 less $T/tests/test_zip:non-existent-file	# nonexisting file in a zip archive git #1, needs unzip
~ 
112 LESS= less tests/dir.zip	# do not colorize listing git #140, needs unzip
~ .* dir/
113 less $T/tests/test\ \;\'\"\[\(\{ok		# file name with chars such as ", ' ...
= test
114 less tests/special.tgz:test\ \;\'\"\[\(\{ok	# archive having a file with chars from [ ;"'] etc. in the name
= test
115 less $T/tests/test\[a\]\(b\)\{c\}.zip	# file name with parens, brackets, braces git #69, needs unzip
~ .*test\[a\]\(b\)\{c\}
116 less $T/tests/test\[a\]\(b\)\{c\}.zip:'test\[a\]\(b\)\{c\}'	# contained file with parens etc., needs unzip
= test
117 less $T/tests/test\[a\]\(b\)\{c\}.zip	# file name with parens, brackets, braces (on the fly), needs unzip
~ .*test\[a\]\(b\)\{c\}
118 less $T/tests/test\[a\]\(b\)\{c\}.zip:'test\[a\]\(b\)\{c\}'	# contained file with parens etc. (on the fly), needs unzip
= test
119 less $T/tests/special.tgz=aaa::b::c::d	# file name with colon (use alternate separator)
= test
120 less $T/tests/symlink			# symbolic link to file name with special chars
= test=a
121 cat $T/tests/test_zip|less			# can use pipes with LESSOPEN =|-... git #2, needs unzip
~ .*10240.*
122 cat $T/tests/test_zip|less - :tests/test.tar	# extract files from piped file, needs unzip
~ .* tests/textfile
123 cat $T/tests/test_zip|less - :tests/test.tar:tests/textfile	# extract files from piped archive, needs unzip
~ test
124 cat $T/tests/test_plain|less	# display piped text files
~ test=a
125 cat $T/tests/test_plain|less - :plain	# display piped plain text files
~ test=a
126 less +F $T/tests/test_plain			# watch growing files with +F git #4
~ test=a
127 less $T/tests/test_plain :			# even watch growing files without +F
~ test=a
128 less $T/tests/test.jar			# support for jar files git #8,22, needs unzip
~ .* META-INF/
129 less tests/compress.tgz:test_zlib	# zlib in archive, needs pigz|zlib-flate
= test
130 less $T/tests/test_zlib		# zlib, needs pigz|zlib-flate
= test
131 less tests/filter.tgz:test.class	# colored java class file git #82, needs procyon
c package
132 LESSCOLORIZER=vimcolor less tests/special.tgz:Dockerfile # colored Dockerfile git #203
c test
133 less tests/archive.tgz:test_cpio # show cpio contents git #206, needs cpio
~ .rw-rw-r .*
134 perldoc $T/tests/test_pod	# do not engage lesspipe twice git #205, needs perldoc
~ ^NAME
EOF
# number of last test
#echo $tests|sed -E '/^[0-9]+ /s/(^[0-9]+).*/\1/'|grep '^[0-9]'|tail -1

# Process tests
nmax=0
while IFS= read -r line ; do
	[[ $line =~ ^### ]] && comment="$line" && continue
	[[ $line =~ ^# ]] || [[ $line =~ ^[\ \	]$ ]] && continue

	num=${line%% *}
	[[ -z $num ]] && continue
	cmds[num]=${line#* }
	[[ -n $comment ]] && comments[num]=$comment && comment=

	read -r line
	comps[num]="$line"
	[[ $nmax -lt $num ]] && nmax=$num
done <<< "$tests"

for ((num = 1 ; num <= nmax ; num++)); do

	cmd="${cmds[num]}"
	comp="${comps[num]}"
	comm="${comments[num]}"

	[[ ${#numtest[@]} -gt 0 && ! " ${numtest[*]} " =~ \ $num\  ]] && continue
	[[ ${#strtest[@]} -gt 0 && ! " ${cmd[*]} " =~ ${strtest[0]} ]] && continue

	comment="${cmd#*[\ \	]#}"
	cmd="${cmd%%[\ \	]#*}"
	cmd="${cmd//\$T/$tmpdir}"
	needed=
	ignore=0

	# force color tests with given colorizer
	if [[ -n "$force_colorizer" ]]; then
		if [[ ${comp:0:1} == c ]]; then
			cmd=${cmd//LESSCOLORIZER/LESSCOLORIZER_NOT}
			for i in "${colorizers[@]}" ; do
				comment=${comment//,!*/}
				comment=${comment//$i/$LESSCOLORIZER}
			done
		else
			continue
		fi
	fi

	if [[ $comment == *\ needs\ * ]]; then
		needed="${comment##* needs }"
		comment=${comment%%, needs*}
		if [[ $needed == *html_converter* ]]; then
			if is_exec w3m || is_exec lynx || is_exec elinks || is_exec html2text; then
				needed="${needed//html_converter/}"
			fi
		fi

		if [[ $needed == *vimcolor* ]]; then
			is_exec vim || is_exec nvim || needed="vim_or_nvim"
		fi
	fi

	[[ -n $comm ]] && echo "$comm"
	if [[ $noaction == 1 ]]; then
		needed_str=${needed:+ "($needed)"}
		[[ $verbose == 1 ]] && echo "$num $cmd$needed_str" || echo "$num $cmd"
		continue
	fi

	[[ -n $needed ]] && ignore=1

	# Split on pipe character (OR)
	# shellcheck disable=SC2207
	needed_arr=($(echo "$needed" | tr '|' ' '))
	for andargs in "${needed_arr[@]}"; do
		good=1
		# Split on comma character (AND)
		# shellcheck disable=SC2207
		and_arr=($(echo "$andargs" | tr ',' ' '))
		for dep in "${and_arr[@]}"; do
			if [[ $dep == !* ]]; then
				dep="${dep#!}"
				! is_exec "$dep" || good=0
			else
				is_exec "$dep" || good=0
			fi
		done
		[[ $good == 1 ]] && ignore=
	done

	if [[ $needed == cpio && $(cpio --version 2>/dev/null) != *GNU* ]]; then
		needed=GNU-cpio
		ignore=1
	fi

	[[ $comp =~ ^c && $colors -lt 8 ]] && ignore=1

	if [[ $ignore == 1 ]]; then
		res=""
	else
		cmd=${cmd%#*}
		res=$(eval "$cmd 2>&1")
	fi

	ok=0
	if [[ $res =~ "command not found:" || $res =~ "not found" ||
		$res =~ "no such file or directory" ]]; then
		res="NOT found: $res"
		ok=1
	else
		if [[ $ignore == 1 ]]; then
			((sumignore++))
		else
			ok=$(compare "$res" "$comp")
			if [[ -n $ok ]]; then
				((sumok++))
			else
				((sumnok++))
			fi
		fi
	fi

	[[ $verbose == 1 ]] && echo -e "result for :$cmd\n$res"
	[[ -z $ok ]] && ok='NOT ok'
	state=$([[ $ignore == 1 ]] && echo ignore || echo "$ok")
	missing=
	[[ $ignore == 1 ]] && missing="needs $needed"
	printf "%3d %-6s %s %s\n" "$num" "$state" "$comment" "$missing"
	[[ $ok == NOT\ ok && $ignore != 1 ]] && echo "    failing command: $cmd"
done

seconds=$(( $(date +%s) - seconds ))
echo "$sumok/$sumignore/$sumnok tests passed/ignored/failed in $seconds seconds"
if [[ -n "$tmpdir" ]]; then
	rm -rf "$tmpdir"
fi
exit $sumnok
