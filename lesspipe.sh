#!/usr/bin/env bash
# lesspipe.sh, a preprocessor for less
lesspipe_version=2.25
# Author: Wolfgang Friebel (wp.friebel AT gmail.com)
# LICENSE: GPL-2.0-or-later

# do not colorize files larger than this size
[[ -n "$LESS_MAXSIZE_COLOR" ]] || LESS_MAXSIZE_COLOR=200000
has_cmd () {
	[[ -n "$2" && "$2" > $($1 --version 2>/dev/null) ]] && return 1
	cmdpath=$(command -v "$1")
	[[ -n $cmdpath && -x $cmdpath ]] && return 0
	return 1
}

fileext () {
	fn=${1##*/}
	case "$fn" in
		.*.*) extension=${fn##*.} ;;
		.*) extension=${fn#.} ;;
		*.*) extension=${fn##*.} ;;
		*) extension="$fn" ;;
	esac
	extension=$(echo "$extension"|tr -dc '[:alnum:]')
	echo "$extension"
}

filetype () {
	# do not depend on the file extension, if possible
	fname="$1"
	if [[ "$1" == - || -z $1 ]]; then
		t=$(nexttmp)
		head -c 1000000 > "$t"
		[[ -z $fileext ]] && fname="$t" || fname="$fileext"
		set "$t" "$2"
	fi
	fext=$(fileext "$fname")
	### get file type from mime type
	ft=$(file -L -s -b --mime "$1" 2> /dev/null)
	[[ $ft == *=* ]] && fchar="${ft##*=}" || fchar=utf-8
	fcat="${ft%/*}"
	ft="${ft#*/}"; ft="${ft%;*}"; ft="${ft#x-script.}"; ft="${ft#x-}"
	ftype="${ft#vnd\.}"
	# chose better name
	case "$ftype" in
		openxmlformats-officedocument.wordprocessingml.document)
			ftype=docx ;;
		openxmlformats-officedocument.presentationml.presentation)
			ftype=pptx ;;
		openxmlformats-officedocument.spreadsheetml.sheet)
			ftype=xlsx ;;
		oasis.opendocument.text*)
			ftype=odt ;;
		oasis.opendocument.spreadsheet)
			ftype=ods ;;
		oasis.opendocument.presentation)
			ftype=odp ;;
		sun.xml.writer)
			ftype=ooffice1 ;;
		shellscript)
			ftype='sh' ;;
		makefile)
			ftype='make' ;;
		epub+zip)
			ftype=epub ;;
		matlab-data)
			ftype=matlab ;;
	# file may report wrong type for given file names (ok in file 5.39)
		troff)
			case "${fname##*/}" in
			[Mm]akefile|[Mm]akefile.*|BSDMakefile)
				ftype='make' ;;
			esac
	esac
	# correct for a more specific file type
	case "$fext" in
		sxi)
			[[ $ftype == zip ]] && ftype=ooffice1 ;;
		epub)
			[[ $ftype == zip ]] && ftype=epub ;;
		ipynb)
			[[ $ftype == json ]] && ftype=ipynb ;;
		mp3)
			[[ $ftype == mpeg ]] && ftype=mp3 ;;
		jsx|csv)
			[[ $fcat == text ]] && ftype="$fext" ;;
		tsx)
			[[ $fcat == text ]] && ftype=typescript-jsx ;;
		appimage|AppImage)
			[[ $fcat == application && -x "$1" ]] && ftype=appimage ;;
		snap)
			[[ $fcat == application ]] && ftype="$fext" ;;
		# do not process dmg files as plain zlib files, if 7z not installed
		dmg)
			[[ $ftype == zlib ]] && ftype=dmg ;;
	esac
	### get file type from 'file' command for an unspecific result
	[[ "$fcat" == message && $ftype == plain ]] && ftype=msg
	[[ "$fcat" == message && $ftype == rfc822 ]] && fcat=text && ftype=email
	if [[ "$fcat" == application && "$ftype" == octet-stream || "$ftype" == pem-file || "$fcat" == text && $ftype == plain ]]; then
		ft=$(file -L -s -b "$1" 2> /dev/null)
		# first check if the file command yields something
		case $ft in
			*mat-file*)
				ftype=matlab ;;
			*POD\ document*)
				ftype=pod ;;
			*PEM\ certificate\ request)
				ftype=csr ;;
			*PEM\ certificate)
				ftype=x509 ;;
			*Microsoft\ OOXML)
				ftype=docx ;;
			Apple\ binary\ property\ list)
				ftype=plist ;;
			PGP\ *ncrypted*|GPG\ encrypted*)
				ftype=pgp ;;
			Audio\ file\ with\ ID3\ *)
				ftype=mp3 ;;
			OpenOffice.org\ 1.x\ Writer\ document)
				ftype=ooffice1 ;;
			*osascript*)
				ftype=applescript ;;
			*Device\ Tree\ Blob*)
				ftype=dtb ;;
			# if still unspecific, determine file type by extension
			data)
				### binary only file formats, type not guessed by 'file'
				case "$fext" in
					mat)
						ftype=matlab ;;
					br|bro|tbr)
						ftype=brotli ;;
					lz4|lt4|tz4|tlz4)
						ftype=lz4 ;;
			esac
		esac
		### decide file type based on extension
		# binary or text file formats
		case "$fext" in
			crt|pem)
				ftype=x509 ;;
			crl|csr)
				ftype="$fext" ;;
		esac
		if [[ $fchar != binary ]]; then
		# text only file formats
			case "$fext" in
				html|htm|xml|pod|log)
					ftype="$fext" ;;
				pm)
					ftype=perl ;;
				md|MD|mkd|markdown|rst)
					ftype=markdown ;;
				ebuild|eclass)
					ftype='sh' ;;
			esac
		fi
	fi

	echo "$ftype:$fchar:$fcat"
}

msg () {
	[[ -n "$LESSQUIET" ]] && return;
	if [[ -n "$lesspipe_version" ]]; then
		echo "==> (lesspipe $lesspipe_version) $*"
	else
		echo "==> $*"
	fi
	lesspipe_version=
}

separatorline () {
	a="==================================="
	word="Contents"
	[[ -n $1 ]] && word=$1
	echo "$a $word $a"
}

nexttmp () {
	new=$(mktemp "$tmpdir/lesspipeXXXXXX")
	# Use the file extension from the original filename if available
	if [[ -n "$fileext" && "$fileext" == *.* ]]; then
		suffix="${fileext##*/}"
		suffix="${suffix##*.}"
	elif [[ "$fileext" && "$ft" == plain:* ]]; then
		suffix="${fileext##*/}"
	elif [[ -z "$1" ]]; then
		suffix="${ft%%:*}"
	else
		suffix="${1##*.}"
	fi
	new2="$new.$suffix"
	mv -n "$new" "$new2"
	echo "$new2"
}

istemp () {
	prog="$1"
	shift
	if [[ "$1" == - ]]; then
		shift
		t=$(nexttmp)
		cat > "$t"
		$prog "$t" "$@"
	else
		$prog "$@"
	fi
}

nodash () {
	prog="$1"
	shift
	[[ "$1" == - ]] && shift
	$prog "$@"
}

show () {
	if [[ "$1" == https://* ]]; then
		x=html
		isfinal "$1"
		return
	fi
	file1="${1%%"$sep"*}"
	rest1="${1#"$file1"}"
	while [[ "$rest1" == "$sep$sep"* ]]; do
		[[ "$rest1" == "$sep$sep" ]] && break
		rest1="${rest1#"$sep$sep"}"
		file1="${rest1%%"$sep"*}"
		rest1="${rest1#"$file1"}"
		file1="${1%"$rest1"}"
	done
	[[ ! -e "$file1" && "$file1" != '-' ]] && exit 1
	rest11="${rest1#"$sep"}"
	file2="${rest11%%"$sep"*}"
	rest2="${rest11#"$file2"}"
	while [[ "$rest2" == "$sep$sep"* ]]; do
		[[ "$rest2" == "$sep$sep" ]] && break
		rest2="${rest2#"$sep$sep"}"
		file2="${rest2%%"$sep"*}"
		rest2="${rest2#"$file2"}"
		file2="${rest11%"$rest2"}"
	done
	rest2="${rest11#"$file2"}"
	rest11="$rest1"

	if [[ "${cmd[*]}" == "" ]]; then
		ft=$(filetype "$file1")
		get_unpack_cmd "$ft" "$file1" "$rest1"
		if [[ "${cmd[*]}" != "" ]]; then
			show "-$rest1"
		else
			# if nothing to convert, exit without a command
			isfinal "$file1" "$rest11"
		fi
	elif [[ "$c1" == "" ]]; then
		c1=("${cmd[@]}")
		ft=$("${c1[@]}" | filetype -) || exit 1
		get_unpack_cmd "$ft" "$file1" "$rest1"
		if [[ "${cmd[*]}" != "" ]]; then
			show "-$rest1"
		else
			"${c1[@]}" | isfinal - "$rest11"
		fi
	elif [[ "$c2" == "" ]]; then
		c2=("${cmd[@]}")
		ft=$("${c1[@]}" | "${c2[@]}" | filetype -) || exit 1
		get_unpack_cmd "$ft" "$file1" "$rest1"
		if [[ "${cmd[*]}" != "" ]]; then
			show "-$rest1"
		else
			"${c1[@]}" | "${c2[@]}" | isfinal - "$rest11"
		fi
	elif [[ "$c3" == "" ]]; then
		c3=("${cmd[@]}")
		ft=$("${c1[@]}" | "${c2[@]}" | "${c3[@]}" | filetype -) || exit 1
		get_unpack_cmd "$ft" "$file1" "$rest1"
		if [[ "${cmd[*]}" != "" ]]; then
			show "-$rest1"
		else
			"${c1[@]}" | "${c2[@]}" | "${c3[@]}" | isfinal - "$rest11"
		fi
	elif [[ "$c4" == "" ]]; then
		c4=("${cmd[@]}")
		ft=$("${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | filetype -) || exit 1
		get_unpack_cmd "$ft" "$file1" "$rest1"
		if [[ "${cmd[*]}" != "" ]]; then
			show "-$rest1"
		else
			"${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | isfinal - "$rest11"
		fi
	elif [[ "$c5" == "" ]]; then
		c5=("${cmd[@]}")
		ft=$("${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | "${c5[@]}" | filetype -) || exit 1
		get_unpack_cmd "$ft" "$file1" "$rest1"
		if [[ "${cmd[*]}" != "" ]]; then
			echo "$0: Too many levels of encapsulation"
		else
			"${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | "${c5[@]}" | isfinal - "$rest11"
		fi
	fi
}

get_unpack_cmd () {
	fchar="${1%:*}"; fchar="${fchar#*:}"
	fcat="${1##*:}"
	x="${1%%:*}"
	cmd=()
	[[ "$3" == $sep$sep ]] && return
	# uncompress / transform
	case $x in
		gzip|bzip2|lzip|lzma|xz|brotli|compress)
			# remember name of uncompressed file
			[[ $2 == - ]] || fileext="$2"
			fileext=${fileext%%.gz}; fileext=${fileext%%.bz2}
			[[ $x == compress ]] && x=gzip
			has_cmd "$x" && cmd=("$x" -cd "$2") ;;
		zstd)
			has_cmd zstd && cmd=(zstd -cdqM1073741824 "$2") ;;
		lz4)
			has_cmd lz4 && cmd=(lz4 -cdq "$2") ;;
		# xls(x) output looks better if transformed to csv and then displayed
		xlsx)
			{ has_cmd xlsx2csv 0.8.3 && cmd=(xlsx2csv "$2"); } ||
			{ has_cmd in2csv && cmd=(in2csv -f xlsx "$2"); } ||
			{ has_cmd excel2csv && cmd=(istemp excel2csv "$2"); } ;;
		ms-excel)
			{ has_cmd in2csv && cmd=(in2csv -f xls "$2"); } ||
			{ has_cmd xls2csv && cmd=(istemp xls2csv "$2"); } ;;
	esac
	[[ ${cmd[*]} == '' ]] || return
	# convert into utf8

	if [[ -n $charmap && $fchar != binary && $fchar != *ascii && $fchar != "$charmap" && $fchar != unknown* ]]; then
		qm="\033[7m?\033[m" # inverted question mark
		rep=(-c)
		trans=()
		iconv --byte-subst - </dev/null 2>/dev/null && rep=(--unicode-subst="$qm" --byte-subst="$qm" --widechar-subst="$qm") # MacOS
		iconv -f "$fchar" -t "$charmap//TRANSLIT" - </dev/null 2>/dev/null && trans=(-t "$charmap//TRANSLIT")
		msg "append $sep$sep to filename to view the original $fchar encoded file"
		cmd=(nodash iconv "${rep[@]}" -f "$fchar" "${trans[@]}" "$2")
		# loop protection, just in case
		charmap=
		return
	fi
	[[ "$3" == "$sep" && "$COLOR" != --color=always ]] && return
	file2=${3#"$sep"}
	file2=${file2%%"$sep"*}
	# remember name of file to extract or file type
	[[ -n "$file2" ]] && fileext="$file2"
	# extract from archive
	rest1="$rest2"
	rest2=
	prog=
	case "$x" in
		tar)
			prog=tar
			has_cmd bsdtar && prog=bsdtar ;;
		rpm)
			{ has_cmd cpio && has_cmd rpm2cpio; } ||
			{ has_cmd bsdtar; } && cmd=(isrpm "$2" "$file2") ;;
		java-archive|zip)
			{ has_cmd bsdtar && prog=bsdtar; } ||
			{ has_cmd unzip && prog=unzip; } ;;
		debian*-package)
			{ has_cmd ar || has_cmd bsdtar; } && cmd=(isdeb "$2" "$file2") ;;
		rar)
			{ has_cmd bsdtar && prog=bsdtar; } ||
			{ has_cmd unrar && prog=unrar; } ||
			{ has_cmd rar && prog=rar; } ;;
		ms-cab-compressed)
			{ has_cmd bsdtar && prog=bsdtar; } ||
			{ has_cmd cabextract && prog=cabextract; } ;;
		iso9660-image)
			{ has_cmd bsdtar && prog=bsdtar; } ||
			{ has_cmd isoinfo && prog=isoinfo; } ;;
		cpio)
			{ has_cmd cpio && prog=cpio; } ||
			{ has_cmd bsdtar && prog=bsdtar; } ;;
		archive)
			{ has_cmd ar && prog='ar'; } ||
			{ has_cmd bsdtar && prog=bsdtar; } ;;
		appimage|snap)
			has_cmd unsquashfs && cmd=(isimage "$x" "$2" "$file2") ;;
	esac
	# 7z formats and fall back to 7z supported formats
	if [[ -z $prog ]]; then
		case "$x" in
			dmg)
				has_cmd 7z && 7z l "$2" >/dev/null 2>&1 && prog=7z ;;
			7z-compressed|lzma|xz|cab|arj|bzip2|cpio|iso)
				{ has_cmd 7zz && prog=7zz; } ||
				{ has_cmd 7zr && prog=7zr; } ||
				{ has_cmd 7z && prog=7z; } ||
				{ has_cmd 7za && prog=7za; } ;;
		esac
	fi
	if [[ "$prog" = ar && "$2" = *@* ]]; then
		t=$(nexttmp)
		cat "$2" > "$t"
		set "$2" "$t"
	fi
	[[ -n $prog ]] && cmd=(isarchive "$prog" "$2" "$file2")
	if [[ -n ${cmd[*]} ]]; then
		[[ -n "$file2" ]] && file2= && return
		msg "use ${x}_file${sep}contained_file to view a file in the archive"
		[[ $3 != "$sep" && $COLOR == --color=always ]] && has_cmd archive_color && colorizer=(archive_color) || colorizer=(no_archive_color)
	fi
}

analyze_args () {
	# determine how we are called
	cmdtree=$(ps -oargs= 2>/dev/null)
	while read -r line; do
		arg1=${line%% *}; arg1=${arg1##*/}
		[[ $arg1 == less ]] && lessarg=$line
	done <<< "$cmdtree"
	# last argument starting with colon or equal sign is used for piping into less
	[[ $lessarg == *\ [:=]* ]] && fext=${lessarg#*[:=]}
	# return if we want to watch growing files
	[[ $lessarg == *less\ *\ : ]] && exit 0
	[[ $lessarg == *less\ *\+F\ * && $fext != log ]] && exit 0
	# color is set when calling less with -r or -R or LESS contains that option
	COLOR="--color=auto"
	colors=0
	[[ $TERM == *256* ]] && colors=256
	has_cmd tput && colors=$(tput colors)
	if [[ $colors -ge 8 ]]; then
		lessarg="$LESS $lessarg"
		# shellcheck disable=SC2206
		r_string=($lessarg)
		for i in "${r_string[@]}"
		do
			[[ $i = --raw-control-chars || $i = --RAW-CONTROL-CHARS ]] && COLOR="--color=always"
			[[ $i = --* ]] && continue
			[[ $i = -- ]] && break
			[[ $i =~ ^-[aABcCdeEfFgGiIJKLmMnNqQsSuUwWX~]*[rR] ]] && COLOR="--color=always"
		done
	fi
}

find_colorizer () {
	prog=${LESSCOLORIZER%% *}
	# Handle vim/vimcolor special case
	[[ $prog == *vimcolor ]] && ! has_cmd vim && ! has_cmd nvim && prog=
	if [[ -z $prog ]]; then
		for i in nvimpager batcat bat pygmentize e2ansi-cat source-highlight vim nvim code2color ; do
			has_cmd "$i" && prog=$i && break
		done
		[[ $prog == *vim ]] && prog=vimcolor
	else
		has_cmd "$prog" || prog=
	fi
	echo "$prog"
}

check_lang () {
	prog=$1
	lang=$2
	[[ -z $lang ]] && return
	case $prog in
		bat|batcat)
			lang=$(echo "$lang"|tr '[:upper:]' '[:lower:]')
			languages=$($prog --list-languages|sed "s/^/:/;s/$/:/;s/\n/:/;s/,/:/g"|tr '[:upper:]' '[:lower:]') ;;
		code2color)
			languages=$($prog -L|sed "s/^/:/;s/$/:/;s/[ ]/:/g")
			languages=${languages##*languages} ;;
		vimcolor|nvimpager)
			languages=$(vimcolor -L "$lang"|sed "s/^/:/;s/$/:/;s/ /:/g") ;;
		source-highlight)
			languages=$($prog --lang-list|sed "s/ =.*//;s/^/:/;s/$/:/;") ;;
		pygmentize)
			$prog -l "$lang" /dev/null &>/dev/null && languages=":$lang:" ;;
		e2ansi-cat)
			echo ''|e2ansi-cat -- --mode "$lang" - >/dev/null 2>&1 && languages=":$lang:" ;;
		*)
			;;
	esac
	[[ $languages == *:$lang:* ]] || lang=
	echo "$lang"
}

colorizer_cmd () {
	prog=$1
	file=$2
	[[ $file == - && -n $final_name ]] && file=$final_name
	lang=$3
	case $prog in
		pygmentize)
			# let pygmentite guess the language if not set and input from pipe
			[[ -n $lang ]] && opt=(-l "$lang")
			[[ $file == - && -z $lang ]] && opt=(-g)
			[[ -n $LESSCOLORIZER && $LESSCOLORIZER = *-[OP]\ *style=* ]] && style="${LESSCOLORIZER/*style=/}"
			[[ -n $style ]] && opt+=(-O style="${style%% *}")
			[[ $colors -ge 256 ]] && opt+=(-f terminal256)
			[[ "$file" == - ]] || opt+=("$file") ;;
		source-highlight)
			[[ -n $lang ]] && opt=(-s "${lang##*.}")
			style=esc
			[[ $colors -ge 256 ]] && style=esc256
			opt+=(--failsafe -f "$style" --style-file "$style".style)
			[[ "$file" == - ]] || opt+=(-i "$file") ;;
		code2color|vimcolor)
			[[ -n $lang ]] && opt=(-l "$lang")
			opt+=("$file") ;;
		nvimpager)
			opt=(-c --)
			[[ -n $lang ]] && opt+=(-c "set filetype=$lang")
			opt+=("$file") ;;
		e2ansi-cat)
			opt=(-- "$file")
			[[ -n $lang ]] && opt=(-- --mode "$lang" "$file") ;;
		bat|batcat)
			[[ -n $lang ]] && opt=(-l "$lang")
			batconfig=$($prog --config-file 2>/dev/null)
			# Extract style and theme from LESSCOLORIZER
			opt2=${LESSCOLORIZER##*--}
			[[ $opt2 == style=* ]] && style=${opt2##*=}
			[[ $opt2 == theme=* ]] && theme=${opt2##*=}
			opt2=$(echo "$LESSCOLORIZER" | tr -s ' ')
			opt2=${opt2%[ ]--*}
			opt2=${opt2##*--}
			[[ $opt2 == style=* ]] && style=${opt2##*=}
			[[ $opt2 == theme=* ]] && theme=${opt2##*=}
			# Sanitize theme (apostroph or backslash in theme names with spaces)
			[[ -n $theme ]] && theme=$(echo "${theme##*=}" | tr -d '/"\047\134/')
			# Apply defaults from config or environment
			[[ -z $style ]] && style=$BAT_STYLE
			[[ -z $theme ]] && theme=$BAT_THEME
			if [[ -r "$batconfig" ]]; then
				[[ -z $style ]] && { grep -q -e '^--style' "$batconfig" || style=plain; }
				[[ -z $theme ]] && { grep -q -e '^--theme' "$batconfig" || theme=ansi; }
			else
				[[ -z $style ]] && style=plain
				[[ -z $theme ]] && theme=ansi
			fi
			style="${style%% *}" theme="${theme%%[|&;<>]*}"
			opt+=(${style:+--style="$style"} ${theme:+--theme="$theme"})
			opt+=("$COLOR" --paging=never "$file") ;;
		*)
			;;
	esac
	[[ -n $LESSCOLORIZER && -z $prog ]] && msg "$LESSCOLORIZER not found"
	colorizer=("$prog" "${opt[@]}")
}

has_colorizer () {
	[[ $COLOR == *always ]] || return
	[[ $(wc -c  < "$1") -lt $LESS_MAXSIZE_COLOR ]] || return
	[[ $2 == plain || -z $2 ]] && return
	prog=$(find_colorizer)
	# prefer an explicitly requested language
	[[ "$2" =~ ^[0-9]*$ || -z "$2" ]] || reql=$2
	# if input is from a pipe use the suffix as language hint
	[[ $1 == - ]] && lang=$3

	pname=${prog##*/}
	! has_cmd "$pname" && pname= && prog=

	lang="$(check_lang "$pname" "$reql")"
	if [[ -z "$lang" && $1 == - && -n $3 ]]; then
		lang=$3
		[[ $lang == *.* ]] && lang=${lang##*.}
		lang="$(check_lang "$pname" "$lang")"
	fi
	# set colorizer name, options and file name to process
	colorizer_cmd "$pname" "$1" "$lang"
}

isfinal () {
	[[ $x == plain && -n $fext ]] && x="$fext"
	if [[ "$2" == *$sep ]]; then
		if [[ "$2" == "$sep" && "$x" == html ]]; then
			[[ $COLOR == *always ]] && colarg="--color" || colarg="--mono"
			has_cmd xmq 'xmq: 4.0' && isxmq "$1" html && return
		fi
		cat "$1"
		return
	fi
	if [[ -z "${cmd[*]}" ]]; then
	# respect extension set by user
	[[ -n "$file2" && "$fileext" == "$file2" && "$fileext" != *.* ]] && x="$fileext"
	case "$x" in
		directory)
			cmd=(ls -lA "$COLOR" "$1")
			if ! ls "$COLOR" > /dev/null 2>&1; then
				cmd=(CLICOLOR_FORCE=1 ls -lA -G "$1")
				if ! ls -lA -G > /dev/null 2>&1; then
					cmd=(ls -lA "$1")
				fi
			fi
			msg="$x: showing the output of ${cmd[*]}" ;;
		xml)
			[[ -z $file2 ]] &&
			has_cmd xmq 'xmq: 4.0' && cmd=(isxmq "$1" xml) ;;
		html)
			[[ -z $file2 ]] && has_htmlprog && cmd=(ishtml "$1") ;;
		dtb|dts)
			has_cmd dtc && cmd=(isdtb "$1") ;;
		pdf)
			{ has_cmd pdftotext && cmd=(istemp pdftotext -layout -nopgbrk -q -- "$1" -); } ||
			{ has_cmd pdftohtml && has_htmlprog && cmd=(istemp ispdf "$1"); } ||
			{ has_cmd pdfinfo && cmd=(istemp pdfinfo "$1"); } ;;
		postscript)
			has_cmd ps2ascii && nodash ps2ascii "$1" 2>/dev/null ;;
		java-applet)
			# filename needs to end in .class
			fileext='java'
			t=$(nexttmp 'class')
			has_cmd procyon && cat "$1" > "$t" && cmd=(JAVA_TOOL_OPTIONS=-DAnsi=true procyon "$t") ;;
		docx)
			{ has_cmd pandoc && cmd=(pandoc -f docx -t plain "$1"); } ||
			{ has_cmd docx2txt && cmd=(docx2txt "$1" -); } ||
			{ has_cmd libreoffice && cmd=(isoffice2 "$1"); } ;;
		pptx)
			{ has_cmd pptx2md && has_cmd pandoc && t2=$(nexttmp) &&
				istemp "pptx2md --disable-image --disable-wmf -o $t2" "$1" && \
					cmd=(pandoc -f markdown -t plain "$t2"); } ||
			{ can_do_office && cmd=(isoffice "$1" ppt); } ;;
		xlsx|ods)
			{ has_cmd xlscat && cmd=(istemp "xlscat -L -R all" "$1"); } ||
			{ can_do_office && cmd=(isoffice "$1" "$x"); } ;;
		odt)
			{ has_cmd odt2txt && cmd=(istemp odt2txt "$1"); } ||
			{ has_cmd pandoc && cmd=(pandoc -f odt -t plain "$1"); } ||
			{ has_cmd libreoffice && cmd=(isoffice2 "$1"); } ;;
		odp)
			{ can_do_office && cmd=(isoffice "$1" odp); } ;;
		msword)
			t="$1"; [[ "$t" == - ]] && t=/dev/stdin
			{ has_cmd wvText && cmd=(istemp wvText "$t" /dev/stdout); } ||
			{ has_cmd catdoc && cmd=(catdoc "$1"); } ||
			{ has_cmd libreoffice && cmd=(isoffice2 "$1"); } ;;
		ms-powerpoint)
			{ can_do_office && cmd=(isoffice "$1" ppt); } ;;
		ms-excel)
			{ can_do_office && cmd=(isoffice "$1" xls); } ;;
		ooffice1)
			has_cmd odt2txt && cmd=(istemp odt2txt "$1") ;;
		ipynb|epub)
			has_cmd pandoc && cmd=(pandoc -f "$x" -t plain "$1") ;;
		troff)
			fext=$(fileext "$1")
			macro=andoc
			[[ "$fext" == me ]] && macro=e
			[[ "$fext" == ms ]] && macro=s
			{ has_cmd mandoc && cmd=(nodash mandoc "$1"); } ||
			{ has_cmd man && cmd=(man -l "$1"); } ||
			{ [[ $COLOR == *always ]] && has_cmd groff && cmd=(groff -s -p -t -e -Tutf8 -m "$macro" "$1"); } ;;
		rtf)
			{ has_cmd unrtf && cmd=(istemp "unrtf --text" "$1"); } ||
			{ has_cmd libreoffice && cmd=(isoffice2 "$1"); } ;;
		dvi)
			has_cmd dvi2tty && cmd=(istemp "dvi2tty -q" "$1") ;;
		sharedlib)
			has_cmd nm && cmd=(istemp nm "$1") ;;
		pod)
			[[ -z $file2 ]] &&
			{ { has_cmd pod2text && cmd=(pod2text "$1"); } ||
			{ has_cmd perldoc && cmd=(istemp "perldoc -T" "$1"); }; } ;;
		hdf|hdf5)
			{ has_cmd h5dump && cmd=(istemp h5dump "$1"); } ||
			{ has_cmd ncdump && cmd=(istemp ncdump "$1"); } ;;
		matlab)
			has_cmd matdump && cmd=(istemp "matdump -d" "$1") ;;
		djvu)
			has_cmd djvutxt && cmd=(djvutxt "$1") ;;
		x509|crl|pem-file|csr)
			[[ "$x" = csr ]] && x509=req || x509="$x"
			has_cmd openssl && cmd=(istemp "openssl $x509 -text -noout -in" "$1") ;;
		pgp)
			has_cmd gpg && cmd=(gpg --decrypt --quiet --no-tty --batch --yes "$1") ;;
		bplist|plist)
			{ has_cmd plistutil && cmd=(istemp "plistutil -i" "$1"); } ||
			{ has_cmd plutil && cmd=(istemp "plutil -p" "$1"); } ;;
		mp3)
			{ has_cmd ffprobe && cmd=(ffprobe -hide_banner -- "$1"); } ||
			{ has_cmd eyeD3 && cmd=(istemp "eyeD3" "$1"); } ||
			{ has_cmd id3v2 && cmd=(istemp "id3v2 --list" "$1"); } ;;
		log)
			[[ $COLOR == *always* ]] && has_cmd tspin &&
				cmd=(nodash tspin -f "$1") ;;
		csv)
			msg "type -S<ENTER> for better display of very wide tables"
			{ has_cmd csvtable && cmd=(csvtable "$1"); } ||
			{ has_cmd csvlook && cmd=(csvlook -S "$1"); } ||
			{ has_cmd column && cmd=(istemp "column -s	,; -t" "$1"); } ||
			{ has_cmd pandoc && cmd=(pandoc -f csv -t plain "$1"); } ;;
		json)
			[[ $COLOR = *always ]] && opt=(-C .) || opt=(.)
			has_cmd jq && cmd=(jq "${opt[@]}" "$1") ;;
		zlib)
			[[ $1 == - ]] && arg='/dev/stdin' || arg="$1"
			{ has_cmd pigz && pigz -d -z < "$arg" && return ; } ||
			{ has_cmd zlib-flate && zlib-flate -uncompress < "$arg" && return ; } ;;
	esac
	fi
	# not a specific file format
	fext=$(fileext "$1")
	if [[ -z ${cmd[*]} && "$fchar" == binary ]]; then
		if [[ $fcat == audio || $fcat == video || $fcat == image ]]; then
			{ has_cmd ffprobe && [[ $fcat != image ]] && cmd=(ffprobe -hide_banner -- "$1"); } ||
			{ [[ "$1" != '-' ]] && has_cmd mediainfo && cmd=(mediainfo --Full "$1"); } ||
			{ has_cmd exiftool && cmd=(exiftool "$1"); } ||
			{ has_cmd identify && [[ $fcat == image ]] && cmd=(identify -verbose "$1"); }
		else
			cmd=(nodash strings "$1")
		fi
	fi
	if [[ -n ${cmd[*]} && "${cmd[*]}" != "cat" ]]; then
		[[ -z $msg ]] && msg="append $sep to filename to view the original $x file"
		msg "$msg"
	fi
	[[ -n "$file2" ]] && fext="$file2"
	[[ $fcat == text && $x != plain ]] && fext=$x
	[[ -z "$fext" ]] && fext=$(fileext "$fileext")
	fext=${fext##*/}
	[[ -z $fext ]] && fext=$x
	if [[ -n ${cmd[*]} ]]; then
		# TAU: When cmd starts with environment variable settings, bash will refuse to execute it via : "${cmd[@]}"
		# The remedy is simple : Just run it through the "env" command in that case.
		[[ "$cmd" =~ '=' ]] && cmd=(env "${cmd[@]}")
		"${cmd[@]}" 2>&1
	else
		local final_input="$1"
		if [[ -n $fileext && "$1" == - && ${colorizer[0]} != archive_color ]]; then
			final_input=$(nexttmp)
			cat "$1" > "$final_input"
		fi

		[[ -z ${colorizer[*]} ]] && has_colorizer "$final_input" "$fext" "$fileext"
		[[ -n ${colorizer[*]} && $fcat != binary ]] && "${colorizer[@]}" 2>/dev/null && return
		# if fileext set, we need to filter to get rid of .fileext
		[[ -n $fileext && "$1" != - ]] && cat "$1" && return
		cat "$final_input"
	fi
}

isarchive () {
	prog=$1
	[[ "$2" =~ ^[a-z_-]*:.* ]] && echo "$2: remote operation tar host:file not allowed" && return
	if [[ -n $3 ]]; then
		case $prog in
			tar|bsdtar)
				[[ "$2" =~ ^[a-z_-]*:.* ]] && echo "$2: remote operation tar host:file not allowed" && return
				if [[ "$3" =~ .*/$ ]]; then
					$prog Otvf "$2" -- "$3"
				else
					$prog Oxf "$2" -- "$3" 2>/dev/null
				fi
				;;
			rar|unrar)
				istemp "$prog p -inul" "$2" "$3" ;;
			ar)
				istemp "ar p" "$2" "$3" ;;
			unzip)
				istemp "unzip -avp" "$2" "$3" ;;
			cabextract)
				istemp cabextract2 "$2" "$3" ;;
			isoinfo)
				istemp "isoinfo -i" "$2" "-x$3" ;;
			cpio)
				if [[ $(cpio --version) = *GNU* ]]; then
					if [[ "$2" == - ]]; then
						cpio -i --quiet --to-stdout "$3"
					else
						istemp cpio -i --quiet --to-stdout --file "$2" "$3"
					fi
				else
					msg "cpio: this version cannot extract files to a pipe"
				fi ;;
			7z|7zz|7za|7zr)
				istemp "$prog e -so" "$2" "$3"
		esac
	else
		case $prog in
			tar|bsdtar)
				[[ "$2" =~ ^[a-z_-]*:.* ]] && echo "$2: remote operation tar host:file not allowed" && return
				$prog tvf "$2" ;;
			rar|unrar)
				istemp "$prog v" "$2" ;;
			ar)
				istemp "ar vt" "$2" ;;
			unzip)
				istemp "unzip -l" "$2" ;;
			cabextract)
				istemp "cabextract -l" "$2" ;;
			isoinfo)
				t="$2"
				istemp "isoinfo -d -i" "$2"
				isoinfo -d -i "$t"| grep -E '^Joliet' && joliet=J
				separatorline
				isoinfo -fR"$joliet" -i "$t" ;;
			cpio)
				cpio -tv --quiet < "$2" ;;
			7z|7zz|7za|7zr)
				istemp "$prog l" "$2" ;;
		esac
	fi
	[[ $? != 0 && -n $3 ]] && msg ":$!: could not retrieve $3 from $2"
}

cabextract2 () {
	cabextract -pF "$2" "$1"
}

ispdf () {
	istemp pdftohtml -i -q -s -noframes -nodrm -stdout "$1"|ishtml -
}

isimage () {
	if [[ "$1" == appimage ]]; then
		offset="-o $("$2" --appimage-offset)"
	fi
	if [[ -z "$3" ]]; then
		[[ "$1" == snap ]] && has_cmd snap && snap info "$2" && separatorline
		istemp "unsquashfs -d . -llc $offset" "$2"
	else
		istemp "unsquashfs -cat $offset" "$2" "$3"
	fi
}

isrpm () {
	if [[ -z "$2" ]]; then
		if has_cmd rpm; then
			istemp "rpm -qivp --changelog --nomanifest --" "$1"
			separatorline
			[[ $1 == - ]] && set "$t" "$1"
		fi
		if has_cmd bsdtar; then
			bsdtar tvf "$1"
		else
			rpm2cpio "$1" 2>/dev/null|cpio -i -tv 2>/dev/null
		fi
	elif has_cmd bsdtar; then
		bsdtar xOf "$1" "$2"
	else
		rpm2cpio "$1" 2>/dev/null|cpio -i --quiet --to-stdout "$2"
	fi
}

isdeb () {
	if [[ "$1" = - ]]; then
		t=$(nexttmp)
		cat > "$t"
		set "$t" "$2"
	fi
	if has_cmd bsdtar; then
		data=$(bsdtar tf "$1" "data*")
		if [[ -z "$2" ]]; then
			control=$(bsdtar tf "$1" "control*")
			bsdtar xOf "$1" "$control" | bsdtar xOf - ./control
			separatorline
			bsdtar xOf "$1" "$data" | bsdtar tvf -
		else
			bsdtar xOf "$1" "$data" | bsdtar xOf - "$2"
		fi
	else
		if [[ "$1" = *@* ]]; then
			t=$(nexttmp)
			cat "$1" > "$t"
			set "$1" "$t"
		fi
		data=$(ar t "$1"|grep data)
		ft=$(ar p "$1" "$data" | filetype -)
		get_unpack_cmd "$ft" -
		if [[ -z "$2" ]]; then
			control=$(ar t "$1"|grep control)
			ar p "$1" "$control" | "${cmd[@]}" | tar xOf - ./control
			separatorline
			ar p "$1" "$data" | "${cmd[@]}" | tar tvf -
		else
			ar p "$1" "$data" | "${cmd[@]}" | tar xOf - "$2"
		fi
	fi
}

isoffice () {
	t=$(nexttmp)
	t2=$t."$2"
	cat "$1" > "$t2"
	libreoffice --headless --convert-to html --outdir "$tmpdir" "$t2" > /dev/null 2>&1
	ishtml "$t.html"
}

isoffice2 () {
	istemp "libreoffice --headless --cat" "$1" 2>/dev/null
}

isxmq () {
	[[ $XMQ_THEME == dark ]] && colarg="--bg=dark" || colarg="--bg=light";
	[[ $COLOR == *always ]] || colarg="--bg=mono"
	msg "xmq output, append :$2 to the filename to see the (colored) contents"
	xmq "$1" render-terminal "$colarg"
}

isdtb () {
	errors=$(nexttmp)
	has_colorizer "-" "dts" "dts"
	[[ -z "${colorizer[*]}" ]] && colorizer=(cat)
	dtc -I dtb -O dts -o - -- "$1" 2> "$errors" | "${colorizer[@]}"
	if [[ -s "$errors" ]]; then
		separatorline "Warnings"
		cat "$errors"
	fi
}

can_do_office () {
	if has_htmlprog && has_cmd libreoffice; then
		return 0
	fi
	return 1
}

has_htmlprog () {
	if has_cmd w3m || has_cmd lynx || has_cmd elinks || has_cmd html2text; then
		return 0
	fi
	return 1
}

handle_w3m () {
	if [[ "$1" == *\?* ]]; then
		t=$(nexttmp)
		ln -s "$1" "$t"
		set "$t" "$1"
	fi
	nodash "w3m -dump -T text/html" "$1"
}

ishtml () {
	[[ $1 == - ]] && arg1=-stdin || arg1="$1"
	htmlopt=--unicode-snob
	has_cmd html2text && html2text -utf8 </dev/null 2>/dev/null && htmlopt=-utf8
	# 3 lines following can easily be reshuffled according to the preferred tool
	has_cmd elinks && nodash "elinks -dump -force-html" "$1" && return ||
	has_cmd w3m && handle_w3m "$1" && return ||
	has_cmd lynx && lynx -force_html -dump "$arg1" && return ||
	# different versions of html2text existing, force unicode
	[[ "$1" == https://* ]] && return ||
	has_cmd html2text && nodash html2text "$htmlopt" "$1"
}

# the main program
set +o noclobber
[[ -n "$ZSH_VERSION" ]] && setopt shwordsplit
# the current locale in lowercase (or generic utf-8)
charmap="utf-8"
if has_cmd locale ; then
	map=$(locale -k charmap 2>/dev/null|tr '[:upper:]' '[:lower:]')
	eval "$map"
fi
sep=:					# file name separator
altsep='='				# alternate separator character
if [[ -e "$1" && "$1" == *"$sep"* ]]; then
	sep=$altsep
elif [[ "$1" == *"$altsep"* ]]; then
	[[ -e "${1%%"$altsep"*}" ]] && sep=$altsep
fi

tmpdir=$(mktemp -d --tmpdir "lesspipe.XXXXXX") || exit 1
trap 'rm -rf "$tmpdir"; exit 1' SIGINT
trap 'rm -rf "$tmpdir"' EXIT
trap - PIPE

analyze_args
# make LESSOPEN="|- ... " work
[[ $LESSOPEN == *\|\|* ]] && retval=1 || retval=0
if [[ $LESSOPEN == *\|-* && $1 == - ]]; then
	t=$(nexttmp)
	cat > "$t"
	set "$1" "$t"
fi

if [[ -z "$1" && "$0" == */lesspipe.sh ]]; then
	[[ "$0" == /* ]] || pat=$(pwd)/
	if [[ "$SHELL" == *csh ]]; then
		echo "setenv LESSOPEN \"|$pat$0 %s\""
	else
		echo "LESSOPEN=\"|$pat$0 %s\""
		echo "export LESSOPEN"
	fi
else
	# no filtering for file names contained in .lessignore
	if [[ -r "${HOME}/.lessignore" ]]; then
		name="$1"
		while IFS= read -r pattern || [[ -n "$pattern" ]]; do
			[[ -z "$pattern" ]] && continue
			[[ "$pattern" == \#* ]] && continue
			# shellcheck disable=SC2053
			[[ "$name" == $pattern ]] && exit 0
		done < "${HOME}/.lessignore"
	fi
	[[ -x "${HOME}/.lessfilter" ]] && "${HOME}/.lessfilter" "$1" && exit "$retval"
	if has_cmd lessfilter; then
		lessfilter "$1" && exit "$retval"
	fi
	if [[ -z "$1" ]]; then
		LESSQUIET=1
		show -
	else
		show "$@"
	fi
	exit "$retval"
fi
