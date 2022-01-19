#!/usr/bin/env bash
# lesscomplete, a helper script for the _less completion script
# Author: Wolfgang Friebel (wp.friebel AT gmail.com)
#( [[ -n 1 && -n 2 ]] ) > /dev/null 2>&1 || exec zsh -y --ksh-arrays -- "$0" ${1+"$@"}

has_cmd () {
	command -v "$1" > /dev/null
}

fileext () {
	case "$1" in
		.*.*) extension=${1##*.};;
		.*) extension=;;
		*.*) extension=${1##*.};;
	esac
	echo "$extension"
}

filetype () {
	# do not depend on the file extension, if possible
	fname="$1"
	if [[ "$1" == - || -z $1 ]]; then
		declare t=$(nexttmp)
		head -c 40000 > "$t" 2>/dev/null
		set "$t" "$2"
		fname="$fileext"
	fi
	fext=$(fileext "$fname")
	### get file type from mime type
	declare ft=$(file -L -s -b --mime "$1" 2> /dev/null)
	[[ $ft == *=* ]] && fchar="${ft##*=}" || fchar=utf-8
	fcat="${ft%/*}"
	ft="${ft#*/}"; ft="${ft%;*}"; ft="${ft#x-}"
	ftype="${ft#vnd\.}"
	### get file type from 'file' command for an unspecific result
	if [[ "$fcat" == application && "$ftype" == octet-stream ]]; then
		ft=$(file -L -s -b "$1" 2> /dev/null)
		if [[ $ft == data ]]; then
			case "$fext" in
				br|bro|tbr)
					ftype=brotli ;;
				lz4|lt4|tz4|tlz4)
					ftype=lz4 ;;
			esac
		fi
	fi
	echo $ftype:$fchar:$fcat
}

nexttmp () {
	declare new="$tmpdir/lesspipe.$RANDOM"
	echo "$new"
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

show () {
	file1="${1%%$sep*}"
	rest1="${1#"$file1"}"
	while [[ "$rest1" == $sep$sep* ]]; do
		if [[ "$rest1" == $sep$sep ]]; then
			break
		else
			rest1="${rest1#$sep$sep}"
			file1="${rest1%%$sep*}"
			rest1="${rest1#"$file1"}"
			file1="${1%"$rest1"}"
		fi
	done
	if [[ ! -e "$file1" && "$file1" != '-' ]]; then
		exit 1
	fi
	rest11="${rest1#$sep}"
	file2="${rest11%%$sep*}"
	rest2="${rest11#"$file2"}"
	while [[ "$rest2" == $sep$sep* ]]; do
		if [[ "$rest2" == $sep$sep ]]; then
			break
		else
			rest2="${rest2#$sep$sep}"
			file2="${rest2%%$sep*}"
			rest2="${rest2#"$file2"}"
			file2="${rest11%"$rest2"}"
		fi
	done
	rest2="${rest11#"$file2"}"
	rest11="$rest1"

	if [[ "$cmd" == "" ]]; then
		ft=$(filetype "$file1")
		get_unpack_cmd $ft "$file1" "$rest1"
		if [[ "$cmd" != "" && -z $colorizer ]]; then
			show "-$rest1"
		else
			# if nothing to convert, exit without a command
			#[[ $colorizer == cat ]] && colorizer=
			isfinal "$ft" "$file1" "$rest11"
		fi
	elif [[ "$c1" == "" ]]; then
		c1=("${cmd[@]}")
		ft=$("${c1[@]}" | filetype -) || exit 1
		get_unpack_cmd $ft "$file1" "$rest1"
		if [[ "$cmd" != "" && -z $colorizer ]]; then
			show "-$rest1"
		else
			"${c1[@]}" | isfinal "$ft" - "$rest11"
		fi
	elif [[ "$c2" == "" ]]; then
		c2=("${cmd[@]}")
		ft=$("${c1[@]}" | "${c2[@]}" | filetype -) || exit 1
		get_unpack_cmd $ft "$file1" "$rest1"
		if [[ "$cmd" != "" && -z $colorizer ]]; then
			show "-$rest1"
		else
			"${c1[@]}" | "${c2[@]}" | isfinal "$ft" - "$rest11"
		fi
	elif [[ "$c3" == "" ]]; then
		c3=("${cmd[@]}")
		ft=$("${c1[@]}" | "${c2[@]}" | "${c3[@]}" | filetype -) || exit 1
		get_unpack_cmd $ft "$file1" "$rest1"
		if [[ "$cmd" != "" && -z $colorizer ]]; then
			show "-$rest1"
		else
			"${c1[@]}" | "${c2[@]}" | "${c3[@]}" | isfinal "$ft" - "$rest11"
		fi
	elif [[ "$c4" == "" ]]; then
		c4=("${cmd[@]}")
		ft=$("${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | filetype -) || exit 1
		get_unpack_cmd $ft "$file1" "$rest1"
		if [[ "$cmd" != "" && -z $colorizer ]]; then
			show "-$rest1"
		else
			"${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | isfinal "$ft" - "$rest11"
		fi
	elif [[ "$c5" == "" ]]; then
		c5=("${cmd[@]}")
		ft=$("${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | "${c5[@]}" | filetype -) || exit 1
		get_unpack_cmd $ft "$file1" "$rest1"
		if [[ "$cmd" != "" && -z $colorizer ]]; then
			echo "$0: Too many levels of encapsulation"
		else
			"${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | "${c5[@]}" | isfinal "$ft" - "$rest11"
		fi
	fi
}

get_unpack_cmd () {
	fchar="${1%:*}"; fchar="${fchar#*:}"
	fcat="${1##*:}"
	x="${1%%:*}"
	cmd=
	declare t
	# uncompress
	case $x in
		gzip|bzip2|lzip|lzma|xz|brotli|compress)
			# remember name of uncompressed file
			[[ $2 == - ]] || fileext="$2"
			fileext=${fileext%%.gz}; fileext=${fileext%%.bz2}
			[[ $x == compress ]] && x=gzip
			has_cmd $x && cmd=($x -cd "$2") && return ;;
		zstd)
			has_cmd zstd && cmd=(zstd -cdqM1073741824 "$2") && return ;;
		lz4)
			has_cmd lz4 && cmd=(lz4 -cdq "$2") && return ;;
	esac
	[[ "$3" == $sep ]] && return
	file2=${3#$sep}
	file2=${file2%%$sep*}
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
			{ has_cmd cpio || has_cmd bsdtar; } &&
			{ has_cmd rpm2cpio && cmd=(isrpm "$2" "$file2"); } ;;
		java-archive|zip)
			{ has_cmd bsdtar && prog=bsdtar; } ||
			{ has_cmd unzip && prog=unzip; } ;;
		debian*-package)
			has_cmd ar && cmd=(isdeb "$2" "$file2") ;;
		rar)
			{ has_cmd bsdtar && prog=bsdtar; } ||
			{ has_cmd unrar && prog=unrar; } ||
			{ has_cmd rar && prog=rar; } ;;
		ms-cab-compressed)
			{ has_cmd bsdtar && prog=bsdtar; } ||
			{ has_cmd cabextract && prog=cabextract; } ;;
		7z-compressed)
			{ has_cmd bsdtar && prog=bsdtar; } ||
			{ has_cmd 7zr && prog=7zr; } ||
			{ has_cmd 7za && prog=7za; } ;;
		iso9660-image)
			{ has_cmd bsdtar && prog=bsdtar; } ||
			{ has_cmd isoinfo && prog=isoinfo; } ;;
		archive)
			prog=ar
			has_cmd bsdtar && prog=bsdtar
	esac
	[[ -n $prog ]] && cmd=(isarchive "$prog" "$2" "$file2")
	if [[ -n $cmd ]]; then
		[[ -n "$file2" ]] && file2= && return
		colorizer=cat
	fi
}

isfinal () {
	if [[ -n $cmd && $colorizer == 'cat' ]]; then
		"${cmd[@]}"
	fi
}

isarchive () {
	prog=$1
	if [[ -n $3 ]]; then
		case $prog in
			tar|bsdtar)
				$prog Oxf "$2" "$3" 2>/dev/null;;
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
			7za|7zr)
				istemp "$prog e -so" "$2" "$3"
		esac
	else
		case $prog in
			tar|bsdtar)
				$prog tf "$2" ;;
			rar|unrar)
				istemp "$prog v" "$2"|egrep ':[0-9][0-9]	'|cut -c 67- ;;
			ar)
				istemp "ar t" "$2" ;;
			unzip)
				istemp "unzip -Z -1" "$2" ;;
			cabextract)
				istemp "cabextract -l" "$2" |egrep '[0-9] \|'|sed 's/.*| //' ;;
			isoinfo)
				t="$2"
				istemp "isoinfo -d -i" "$2" >/dev/null
				istemp "isoinfo -d -i" "$t"| grep -E '^Joliet' && joliet=J
				isoinfo -fR$joliet -i "$t" ;;
			7za|7zr)
				$prog l "$2"|egrep '^[0-9][0-9][0-9[0-9]'|cut -c 54-|egrep -v ' files$'
		esac
	fi
}

cabextract2 () {
	cabextract -pF "$2" "$1"
}

isrpm () {
	if [[ -z "$2" ]]; then
		if has_cmd bsdtar; then
			rpm2cpio "$1" 2>/dev/null | bsdtar tf -
		else
			rpm2cpio "$1" 2>/dev/null|cpio -i -t 2>/dev/null
		fi
	elif has_cmd bsdtar; then
		rpm2cpio "$1" 2>/dev/null | bsdtar xOf - "$2"
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
			bsdtar xOf "$1" "$data" | bsdtar tf -
		else
			bsdtar xOf "$1" "$data" | bsdtar xOf - "$2"
		fi
	else
		data=$(istemp "ar t" "$1"|grep data)
		ft=$(ar p "$1" "$data" | filetype -)
		get_unpack_cmd $ft -
		if [[ -z "$2" ]]; then
			istemp "ar p" "$1" "$data" | ${cmd[@]} | tar tf -
		else
			ar p "$1" "$data" | ${cmd[@]} | tar xOf - "$2"
		fi
	fi
}

# the main program
set +o noclobber
setopt sh_word_split 2>/dev/null

sep=:												# file name separator
altsep==										# alternate separator character
if [[ -e "$1" && "$1" == *$sep* ]]; then
	sep=$altsep
elif [[ "$1" == *$altsep* ]]; then
	[[ -e "${1%%$altsep*}" ]] && sep=$altsep
elif [[ "$1" == ~* ]]; then
	set $HOME${1#\~} $1
fi

tmpdir=${TMPDIR:-/tmp}/lesspipe."$RANDOM"
[[ -d "$tmpdir" ]] || mkdir "$tmpdir"
[[ -d "$tmpdir" ]] || exit 1
trap "rm -rf '$tmpdir';exit 1" INT
trap "rm -rf '$tmpdir'" EXIT
trap - PIPE

t=$(nexttmp)
# make LESSOPEN="|- ... " work
if [[ $LESSOPEN == *\|-* && $1 == - ]]; then
	cat > $t
	[[ -n "$fext" ]] && t="$t$sep$fext"
	set $1 "$t"
	nexttmp >/dev/null
fi

show "$@"
