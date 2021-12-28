#!/usr/bin/env bash
# lesspipe.sh, a preprocessor for less (version 2.00-beta)
# Author:  Wolfgang Friebel (wp.friebel AT gmail.com)
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
  fext=$("fileext" "$fname")
  ### get file type from mime type
  declare ft=$(file -L -s -b --mime "$1" 2> /dev/null)
  fchar="${ft##*=}"
  fcat="${ft%/*}"
  ft="${ft#*/}"; ft="${ft%;*}"; ft="${ft#x-}"
  ftype="${ft#vnd\.}"
  # chose better name
  case "$ftype" in
    openxmlformats-officedocument.wordprocessingml.document)
      ftype=docx ;;
    openxmlformats-officedocument.presentationml.presentation)
      ftype=pptx ;;
    openxmlformats-officedocument.spreadsheetml.sheet)
      ftype=xlsx ;;
    oasis.opendocument.text)
      ftype=odt ;;
    oasis.opendocument.spreadsheet)
      ftype=ods ;;
    oasis.opendocument.presentation)
      ftype=odp ;;
    sun.xml.writer)
      ftype=ooffice1 ;;
    shellscript)
      ftype=sh ;;
    makefile)
      ftype=make ;;
    epub+zip)
      ftype=epub ;;
  # chose another file type which can handle the current one
    compress)
      ftype=gzip ;;
  # file may report wrong type for given file names (ok in file 5.39)
    troff)
      case "${fname##*/}" in
      [Mm]akefile|[Mm]akefile.*|BSDMakefile)
        ftype=make ;;
      esac
  esac
  # correct for a more specific file type
  case "$fext" in
    epub)
      [[ $ftype == zip ]] && ftype=epub ;;
    ipynb)
      [[ $ftype == json ]] && ftype=ipynb ;;
    mp3)
      [[ $ftype == mpeg ]] && ftype=mp3 ;;
  esac
  ### get file type from 'file' command for an unspecific result
  if [[ "$fcat" == application && "$ftype" == octet-stream || "$fcat" == text && $ftype == plain ]]; then
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
        ftype=csr ;;
      Apple\ binary\ property\ list)
        ftype=plist ;;
      PGP\ *ncrypted*|GPG\ encrypted*)
        ftype=pgp ;;
      Audio\ file\ with\ ID3\ *)
        ftype=mp3 ;;
      # if still unspecific,  determine file type by extension
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
      crl)
        ftype=crl ;;
      csr)
        ftype=csr ;;
    esac
    if [[ $fchar != binary ]]; then
    # text only file formats
      case "$fext" in
        pod)
          ftype=pod ;;
        pm)
          ftype=perl ;;
        crt|pem)
          ftype=x509 ;;
        crl)
          ftype=crl ;;
        csr)
          ftype=csr ;;
        md|MD|mkd|markdown|rst)
          ftype=markdown ;;
        log)
          ftype=log ;;
        ebuild|eclass)
          ftype=sh ;;
      esac
    fi
  fi
  echo $ftype:$fchar:$fcat
}

msg () {
  [[ -n "$LESSQUIET" ]] && return;
  echo "==> $@"
}

contentline () {
  declare a="==================================="
  echo "$a Contents $a"
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

nodash () {
  prog="$1"
  shift
  [[ "$1" == - ]] && shift
  $prog "$@"
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
      [[ $colorizer == cat ]] && colorizer=
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
  if [[ "$3" == $sep$sep ]]; then
    return
  fi
  declare t
  # uncompress / transform
  case $x in
    gzip|bzip2|lzip|lzma|xz|brotli)
      # remember name of uncompressed file
      [[ $2 == - ]] || fileext="$2"
      fileext=${fileext%%.gz}; fileext=${fileext%%.bz2}
      has_cmd $x && cmd=($x -cd "$2") && return ;;
    zstd)
      has_cmd zstd && cmd=(zstd -cdqM1073741824 "$2") && return ;;
    lz4)
      has_cmd lz4 && cmd=(lz4 -cdq "$2") && return ;;
  esac
  # convert into utf8

  if [[ -n $lclocale && $fchar != binary && $fchar != *ascii && $fchar != $lclocale ]]; then
    qm="\033[7m?\033[m" # inverted question mark
    rep=-c
	trans=
    echo ""|iconv --byte-subst - 2>/dev/null && rep="--unicode-subst=$qm --byte-subst=$qm --widechar-subst=$qm" # MacOS
	echo ""|iconv -f $fchar -t $locale//TRANSLIT - 2>/dev/null && trans="-t $locale//TRANSLIT"
	msg "append $sep$sep to filename to view the $fchar encoded file"
    cmd=(iconv $rep -f $fchar $trans "$2")
	# loop protection, just in case
	lclocale=
    return
  fi
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
      { has_cmd rpm2cpio || has_cmd rpmunpack; } && cmd=(isrpm "$2" "$file2") ;;
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
      { has_cmd 7zr && prog=7zr; } ||
      { has_cmd 7za && prog=7za; } ;;
    iso9660-image)
      { has_cmd bsdtar && prog=bsdtar; } ||
      { has_cmd isoinfo && prog=isoinfo; } ;;
    archive)
      prog=ar
      has_cmd bsdtar && prog=bsdtar
  esac
  [[ -n $prog ]] && cmd=(isarchive $prog "$2" "$file2")
  if [[ -n $cmd ]]; then
    [[ -n "$file2" ]] && file2= && return
    msg "use ${x}_file${sep}contained_file to view a file in the archive"
    has_cmd archive_color && colorizer=archive_color || colorizer=cat
  fi
}

analyze_args () {
  # determine how we are called
  cmdtree=`ps -T -opid= -oargs=`
  # adjust, if we are called from the test suite
  [[ $cmdtree =~ ./test.pl\ .* || $cmdtree =~ ./test.pl ]] && addmatch='[0-9]* '
  cmdtree=`echo $cmdtree|sed "s/[0-9]* $addmatch//;s/ [0-9]* /;/g;s/^[^;]*;//"`
  lessarg=${cmdtree%%;*}
  [[ $lessarg == *test.pl\ * ]] && lessarg=${cmdtree##$lessarg;*}
  # return if we want to watch growing files
  [[ $lessarg == *less\ *\ +F\ * || $lessarg == *less\ *\ : ]] && exit 0
  # if lesspipe is called in pipes, return immediately for some use cases
  if [[ $LESSOPEN == *-* ]]; then
    # man pandoc output errorneously recognized as html
    case $lessarg in
      man\ *|*/man\ *|*/perldoc\ *|git\ *)
        exit 0
    esac
  fi
  # color is set when calling less with -r or -R or LESS contains that option
  lessarg="$LESS $lessarg"
  lessarg=`echo $lessarg|sed 's/-[a-zA-Z]*[rR]/-r/'`
  has_cmd tput && colors=$(tput colors) || colors=0
  if [[ $colors -ge 8 && $lessarg == *-[rR]* ]]; then
    COLOR="--color=always"
  else
    COLOR="--color=auto"
  fi
  # last argument starting with colon or equal sign is used for piping into less
  [[ $lessarg == *\ [:=]* ]] && fext=${lessarg#*[:=]}
}

has_colorizer () {
  arg="$1"
  [[ "$arg" = - ]] && arg=
  [[ $COLOR == *always ]] || return
  [[ $2 == plain || -z $2 ]] && return
  prog=${LESSCOLORIZER%% *}

  for i in bat batcat pygmentize source-highlight code2color vimcolor ; do
    [[ -z $prog || $prog == $i ]] && has_cmd $i && prog=$i
  done
  [[ "$2" =~ ^[0-9]*$ ]] && opt= || opt=" -l $2"
  case $prog in
    bat|batcat)
      opt="$opt $COLOR" ;;
    pygmentize)
		[[ -n $LESSCOLORIZER && $LESSCOLORIZER =~ pygmentize\ \ *-O\ *style=[a-z]* ]] && prog=$LESSCOLORIZER
		[[ $colors -ge 256 ]] && prog="$prog -f terminal256"
		res=$(pygmentize -l $2 /dev/null 2>/dev/null) && opt=" -l $2" || opt=" -g" ;;
    source-highlight)
      prog="source-highlight --failsafe -f esc"
      [[ -z $arg ]] && arg=/dev/stdin
      [[ -n $opt ]] && opt=" -s $2 -i" || opt=" -i" ;;
    code2color)
      [[ -n $opt ]] && opt=" -i .$2" ;;
    vimcolor)
      ;;
    *)
      return ;;
  esac
  echo "$prog$opt $arg"
}

isfinal () {
  if [[ "$3" == *$sep ]]; then
    cat "$2"
    return
  fi
  if [[ -z "$cmd" ]]; then
  # respect extension set by user
  [[ -n "$file2" && "$fileext" == "$file2" && "$fileext" != *.* ]] && x="$fileext"
  case "$x" in
    directory)
      cmd=(ls -lA $COLOR "$2")
      if ! ls $COLOR > /dev/null 2>&1; then
        cmd=(CLICOLOR_FORCE=1 ls -lA -G "$2")
        if ! ls -lA -G > /dev/null 2>&1; then
          cmd=(ls -lA "$2")
        fi
      fi
      msg="$x: showing the output of ${cmd[@]}" ;;
    html|xml)
      [[ -z $file2 ]] && has_htmlprog && cmd=(ishtml "$2") ;;
    pdf)
      { has_cmd pdftotext && cmd=(istemp pdftotext -layout -nopgbrk -q -- "$2" -); } ||
      { has_cmd pdftohtml && has_htmlprog && cmd=(istemp ispdf "$2"); } ||
      { has_cmd pdfinfo && cmd=(istemp pdfinfo "$2"); } ;;
    postscript)
      has_cmd ps2ascii && nodash ps2ascii "$2" ;;
    java-applet)
      # filename needs to end in .class
      has_cmd procyon && t=$t.class && cat "$2" > $t && cmd=(procyon "$t") ;;
    markdown)
      { has_cmd mdcat && cmd=(mdcat "$2"); } ||
      { has_cmd pandoc && cmd=(pandoc -t plain "$2"); } ;;
    docx)
      { has_cmd pandoc && cmd=(pandoc -f docx -t plain "$2"); } ||
      { has_cmd docx2txt && cmd=(docx2txt "$2" -); } ||
      { has_cmd libreoffice && cmd=(isoffice2 "$2"); } ;;
    pptx)
      { has_cmd pptx2md && t2=$(nexttmp) &&
        { has_cmd mdcat && istemp "pptx2md --disable-image --disable-wmf \
          -o $t2" "$2" && cmd=(mdcat "$t2"); } ||
        { has_cmd pandoc && istemp "pptx2md --disable-image --disable-wmf \
          -o $t2" "$2" && cmd=(pandoc -f markdown -t plain "$t2"); }; } ||
      { has_cmd libreoffice && has_htmlprog && cmd=(isoffice "$2" ppt); } ;;
    xlsx)
      { has_cmd in2csv && cmd=(in2csv -f xlsx "$2"); } ||
      { has_cmd xlscat && cmd=(istemp xlscat "$2"); } ||
      { has_cmd excel2csv && cmd=(istemp excel2csv "$2"); } ||
      { has_cmd libreoffice && has_htmlprog && cmd=(isoffice "$2" xlsx); } ;;
    odt)
      { has_cmd pandoc && cmd=(pandoc -f odt -t plain "$2"); } ||
      { has_cmd odt2txt && cmd=(istemp odt2txt "$2"); } ||
      { has_cmd libreoffice && cmd=(isoffice2 "$2"); } ;;
    odp)
      { has_cmd libreoffice && has_htmlprog && cmd=(isoffice "$2" odp); } ;;
    ods)
      { has_cmd xlscat && t=$t.ods && cat "$2" > $t &&  cmd=(xlscat "$t"); } ||
      { has_cmd libreoffice && has_htmlprog && cmd=(isoffice "$2" ods); } ;;
    msword)
      t="$2"; [[ "$t" == - ]] && t=/dev/stdin
      { has_cmd wvText && cmd=(istemp wvText "$t" /dev/stdout); } ||
      { has_cmd antiword && cmd=(antiword "$2"); } ||
      { has_cmd catdoc && cmd=(catdoc "$2"); } ||
      { has_cmd libreoffice && cmd=(isoffice2 "$2"); } ;;
    ms-powerpoint)
      { has_cmd broken_catppt && cmd=(istemp catppt "$2"); } ||
      { has_cmd libreoffice && has_htmlprog && cmd=(isoffice "$2" ppt); } ;;
    ms-excel)
      { has_cmd in2csv && cmd=(in2csv -f xls "$2"); } ||
      { has_cmd xls2csv && cmd=(istemp xls2csv "$2"); } ||
      { has_cmd libreoffice && has_htmlprog && cmd=(isoffice "$2" xls); } ;;
    ooffice1)
      { has_cmd sxw2txt && cmd=(istemp sxw2txt "$2"); } ||
      { has_cmd libreoffice && has_htmlprog && cmd=(isoffice "$2" odt); } ;;
    ipynb|epub)
      has_cmd pandoc && cmd=(pandoc -f $x -t plain "$2") ;;
    troff)
      if has_cmd groff; then
        fext=$(fileext "$2")
        declare macro=andoc
        [[ fext == me ]] && macro=e
        [[ fext == ms ]] && macro=s
        cmd=(groff -s -p -t -e -Tutf8 -m$macro "$2")
      fi ;;
    rtf)
      { has_cmd unrtf && cmd=(istemp "unrtf --text" "$2"); } ||
      { has_cmd libreoffice && cmd=(isoffice2 "$2"); } ;;
    dvi)
      has_cmd dvi2tty && cmd=(istemp "dvi2tty -q" "$2") ;;
    sharedlib)
      cmd=(istemp nm "$2");;
    pod)
      [[ -z $file2 ]] && LESSQUIET=1 &&
      { { has_cmd pod2text && cmd=(pod2text "$2"); } ||
      { has_cmd perldoc && cmd=(istemp perldoc "$2"); }; } ;;
    hdf)
      { has_cmd h5dump && cmd=(istemp h5dump "$2"); } ||
      { has_cmd ncdump && cmd=(istemp ncdump "$2"); } ;;
    matlab)
      has_cmd matdump && cmd=(istemp "matdump -d" "$2") ;;
    djvu)
      has_cmd djvutxt && cmd=(djvutxt "$2") ;;
    x509|crl)
      has_cmd openssl && cmd=(istemp "openssl $x -hash -text -noout  -in" "$2") ;;
    csr)
      has_cmd openssl && cmd=(istemp "openssl req -text -noout  -in" "$2") ;;
    pgp)
      has_cmd gpg && cmd=(gpg -d "$2") ;;
    plist)
      has_cmd plistutil && cmd=(istemp "plistutil -i" "$2") ;;
    mp3)
      has_cmd id3v2 && cmd=(istemp "id3v2 --list" "$2") ;;
    log)
      has_cmd ccze && cat "$2" | ccze -A
      return ;;
  esac
  fi
  # not a specific file format
  if [[ -z "$cmd" ]]; then
	fext=$(fileext "$2")
    if [[ $fcat == audio || $fcat == video || $fcat == image ]]; then
      { has_cmd mediainfo && cmd=(mediainfo --Full "$2"); } ||
      { has_cmd exiftools && cmd=(exiftool "$2"); } ||
      { has_cmd identify && $fcat == image && cmd=(identify -verbose "$2"); }
    elif [[ "$fchar" == binary ]]; then
      cmd=(nodash strings "$2")
    fi
  fi
  if [[ -z "$LESSQUIET" && -n $cmd && $cmd != "cat" ]]; then
    [[ -z $msg ]] && msg="append $sep to filename to view the $x file"
    echo $msg
  fi
  if [[ -n $cmd ]]; then
    if [[ $colorizer == archive_color && $COLOR == *always ]]; then
      "${cmd[@]}" | archive_color
    else
      "${cmd[@]}"
    fi
  else
    [[ -n "$file2" ]] && fext="$file2"
    [[ -z "$fext" && $fcat == text && $x != plain ]] && fext=$x
    [[ -z "$fext" ]] && fext=$(fileext "$fileext")
    [[ -z $colorizer ]] && colorizer=$(has_colorizer "$2" "$fext")
    [[ -n $colorizer && $fcat != binary ]] && $colorizer && return
    # if fileext set, we need to filter to get rid of .fileext
    [[ -n $fileext || "$2" == - || "$2" == $t ]] && cat "$2"
  fi
}

isarchive () {
  prog=$1
  [[ "$2" =~ ^[a-z_-]*:.* ]] && echo $2: remote operation tar host:file not allowed && return
  if [[ -n $3 ]]; then
	case $prog in
      tar|bsdtar)
        [[ "$2" =~ ^[a-z_-]*:.* ]] && echo $2: remote operation tar host:file not allowed && return
        $prog Oxf "$2" "$3" 2>&1 ;;
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
        [[ "$2" =~ ^[a-z_-]*:.* ]] && echo $2: remote operation tar host:file not allowed && return
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
        contentline
        isoinfo -fR$joliet -i "$t" ;;
      7za|7zr)
		is7zarchive $prog "$2"
    esac
  fi
}

cabextract2 () {
   cabextract -pF "$2" "$1"
}

ispdf () {
  istemp pdftohtml -i -q -s -noframes -nodrm -stdout "$1"|ishtml -
}

isrpm () {
  if [[ -z "$2" ]]; then
    istemp "rpm -qivp" "$1"
    [[ $1 == - ]] && set "$t" "$1"
    contentline
	if has_cmd bsdtar; then
      if has_cmd rpm2cpio; then
        rpm2cpio "$1" 2>/dev/null | bsdtar tvf -
      elif has_cmd rpmunpack; then
        cat "$1" | rpmunpack | bsdtar tvf -
      fi
    else
      if has_cmd rpm2cpio; then
        rpm2cpio "$1" 2>/dev/null|cpio -i -tv 2>/dev/null
      elif has_cmd rpmunpack; then
        cat "$1" | rpmunpack | gzip -cd | cpio -i --quiet -tv 2>/dev/null
      fi
    fi
  elif has_cmd bsdtar; then
    if has_cmd rpm2cpio; then
      rpm2cpio "$1" 2>/dev/null | bsdtar xOf - "$2"
    elif has_cmd rpmunpack; then
      cat "$1" | rpmunpack | bsdtar xOf - "$2"
    fi
  else
    if has_cmd rpm2cpio; then
      rpm2cpio "$1" 2>/dev/null|cpio -i --quiet --to-stdout "$2"
    elif has_cmd rpmunpack; then
      cat "$1" | rpmunpack | gzip -cd | cpio -i --quiet --to-stdout "$2"
    fi
  fi
}

isdeb () {
  if [[ "$1" = - ]]; then
    t=$(nexttmp)
    cat > "$t"
    set "$t" "$2"
  fi
  if [[ -z "$2" ]]; then
    if has_cmd dpkg; then
      dpkg -I "$1"
    elif has_cmd bsdtar; then
      bsdtar "$1" control.tar.gz | bsdtar xOf - ./control
    else
      istemp ar p "$1" control.tar.gz | gzip -dc - | tar xOf - ./control
    fi
  fi
  data=$(istemp "ar t" "$1"|grep data)
  if has_cmd bsdtar; then
    if [[ -z "$2" ]]; then
      contentline
      bsdtar xOf "$1" "$data" | bsdtar tvf -
    else
      bsdtar xOf "$1" "$data" | bsdtar xOf - "$2"
    fi
  else
    ft=$(ar p "$1" "$data" | filetype -)
    get_unpack_cmd $ft -
    if [[ -z "$2" ]]; then
      contentline
      istemp "ar p" "$1" "$data" | ${cmd[@]} | tar tvf -
    else
      ar p "$1" "$data" | ${cmd[@]} | tar xOf - "$2"
    fi
  fi
}

is7zarchive () {
  prog=$1
  t="$2"
  res=$(istemp "$prog l" "$2")
  if [[ "$res" == *1\ files ]]; then
    name=$(echo $res|tail -3|head -1|awk '{print $6}')
    msg "the 7-zip archive containing only file '$name' was unpacked"
    t=${res#*Listing\ archive:\ }
    t2="
"
    t=${t%%$t2*}
    $prog e -so "$t"
  else
    echo $res
  fi
}

isoffice () {
  t=$(nexttmp)
  t2=$t."$2"
  cat "$1" > $t2
  libreoffice --headless --convert-to html --outdir "$tmpdir" "$t2" > /dev/null 2>&1
  ishtml $t.html
}

isoffice2 () {
  istemp "libreoffice --headless --cat" "$1" 2>/dev/null
}

has_htmlprog () {
  if has_cmd w3m || has_cmd lynx || has_cmd elinks || has_cmd html2text; then
    return 0
  fi
  return 1
}

ishtml () {
  [[ $1 == - ]] && arg1=-stdin || arg1="$1"
  # 3 lines following can easily be reshuffled according to the preferred tool
  has_cmd w3m && nodash "w3m -dump -T text/html" "$1" && return ||
  has_cmd lynx && lynx -force_html -dump "$arg1" && return ||
  has_cmd elinks && nodash "elinks -dump -force-html" "$1" && return ||
  # different incompatible versions with the name html2text may let this fail
  html2text -utf8  || html2text -from_encoding utf-8
  has_cmd html2text && nodash html2text "$1"
}

# the main program
set +o noclobber
setopt sh_word_split 2>/dev/null
PATH=$PATH:${0%%/lesspipe.sh}
# the current locale in lowercase (or generic utf-8)
locale=$(locale|grep LC_CTYPE|sed 's/.*"\(.*\)"/\1/') || locale=en_US.UTF-8
lclocale=$(echo ${locale##*.}|sed 's/\(.*\)/\L\1/')

sep=:                       # file name separator
altsep==                    # alternate separator character
if [[ -e "$1" && "$1" == *$sep* ]]; then
  sep=$altsep
elif [[ "$1" == *$altsep* ]]; then
  [[ -e "${1%$altsep*}" ]] && sep=$altsep
fi

tmpdir=${TMPDIR:-/tmp}/lesspipe."$RANDOM"
[[ -d "$tmpdir" ]] || mkdir "$tmpdir"
[[ -d "$tmpdir" ]] || exit 1
trap "rm -rf '$tmpdir';exit 1" INT
trap "rm -rf '$tmpdir'" EXIT
trap - PIPE

t=$(nexttmp)
analyze_args
# make LESSOPEN="|- ... " work
if [[ $LESSOPEN == *\|-* && $1 == - ]]; then
  cat > $t
  [[ -n "$fext" ]] && t="$t$sep$fext"
  set $1 "$t"
  nexttmp
fi

if [[ -z "$1" ]]; then
  [[ "$0" == /* ]] || pat=$(pwd)/
  if [[ "$SHELL" == *csh ]]; then
    echo "setenv LESSOPEN \"|$pat$0 %s\""
  else
    echo "LESSOPEN=\"|$pat$0 %s\""
    echo "export LESSOPEN"
  fi
else
  show "$@"
fi
