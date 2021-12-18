#!/usr/bin/env bash
# lesspipe.sh, a preprocessor for less (version 2.00-alpha)
# Author:  Wolfgang Friebel (wp.friebel AT gmail.com)
#( [[ -n 1 && -n 2 ]] ) > /dev/null 2>&1 || exec zsh -y --ksh-arrays -- "$0" ${1+"$@"}
set +o noclobber
setopt sh_word_split 2>/dev/null
PATH=$PATH:${0%%/lesspipe.sh}

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
  fname=$1
  if [[ "$1" == - ]]; then
    declare t=$(nexttmp)
    head -c 40000 > "$t" 2>/dev/null
    set "$t" "$2"
    fname=$fileext
  fi
  fext=$(fileext "$fname")
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
  prog=$1
  shift
  if [[ "$1" = - ]]; then
    shift
    t=$(nexttmp)
    cat > "$t"
    $prog "$t" "$@" #2>/dev/null
  else
    $prog "$@" #2>/dev/null
  fi
}

nodash () {
  prog="$1"
  shift
  [[ "$1" == - ]] && shift
  $prog $@
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
    if [[ "$cmd" != "" ]]; then
      show "-$rest1"
    else
      isfinal "$ft" "$file1" "$rest11"
    fi
  elif [[ "$c1" == "" ]]; then
    c1=("${cmd[@]}")
    ft=$("${c1[@]}" | filetype -) || exit 1
    get_unpack_cmd $ft "$file1" "$rest1"
    if [[ "$cmd" != "" ]]; then
      show "-$rest1"
    else
      "${c1[@]}" | isfinal "$ft" - "$rest11"
    fi
  elif [[ "$c2" == "" ]]; then
    c2=("${cmd[@]}")
    ft=$("${c1[@]}" | "${c2[@]}" | filetype -) || exit 1
    get_unpack_cmd $ft "$file1" "$rest1"
    if [[ "$cmd" != "" ]]; then
      show "-$rest1"
    else
       "${c1[@]}" | "${c2[@]}" | isfinal "$ft" - "$rest11"
    fi
  elif [[ "$c3" == "" ]]; then
    c3=("${cmd[@]}")
    ft=$("${c1[@]}" | "${c2[@]}" | "${c3[@]}" | filetype -) || exit 1
    get_unpack_cmd $ft "$file1" "$rest1"
    if [[ "$cmd" != "" ]]; then
      show "-$rest1"
    else
      "${c1[@]}" | "${c2[@]}" | "${c3[@]}" | isfinal "$ft" - "$rest11"
    fi
  elif [[ "$c4" == "" ]]; then
    c4=("${cmd[@]}")
    ft=$("${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | filetype -) || exit 1
    get_unpack_cmd $ft "$file1" "$rest1"
    if [[ "$cmd" != "" ]]; then
      show "-$rest1"
    else
      "${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | isfinal "$ft" - "$rest11"
    fi
  elif [[ "$c5" == "" ]]; then
    c5=("${cmd[@]}")
    ft=$("${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | "${c5[@]}" | filetype -) || exit 1
    get_unpack_cmd $ft "$file1" "$rest1"
    if [[ "$cmd" != "" ]]; then
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
  if [[ $fchar == utf-16le ]]; then
    qm="\033[7m?\033[m" # inverted question mark
    rep=-c
	trans=
    echo ""|iconv --byte-subst - 2>/dev/null && rep="--unicode-subst=$qm --byte-subst=$qm --widechar-subst=$qm" # MacOS
	echo ""|iconv -f UTF-16 -t //TRANSLIT - 2>/dev/null && trans="-t //TRANSLIT"
    cmd=(iconv $rep -f UTF-16 $trans "$2")
    return
  fi
  [[ "$3" == $sep ]] && return
  file2=${3#$sep}
  file2=${file2%%$sep*}
  # remember name of file to extract or file type
  [[ -n "$file2" ]] && fileext="$file2"
  # extract from archive
  rest1=$rest2
  rest2=
  case "$x" in
    tar)
      cmd=(istar "$2" "$file2") ;;
    rpm)
      has_cmd cpio && { has_cmd rpm2cpio || has_cmd rpmunpack; } && cmd=(isrpm "$2" "$file2") ;;
    java-archive|zip)
      has_cmd unzip && cmd=(iszip "$2" "$file2") ;;
    debian*-package)
      cmd=(isdeb "$2" "$file2") ;;
    rar)
        { has_cmd unrar && cmd=(israr unrar "$2" "$file2"); } ||
        { has_cmd rar && cmd=(israr rar "$2" "$file2"); } ||
        { has_cmd bsdtar && cmd=(israr bsdtar "$2" "$file2"); } ;;
    ms-cab-compressed)
      has_cmd cabextract && cmd=(iscab "$2" "$file2") ;;
    7z-compressed)
      { has_cmd 7zr && cmd=(is7zarchive 7zr "$2" "$file2"); } ||
      { has_cmd 7za && cmd=(is7zarchive 7za "$2" "$file2"); } ;;
    iso9660-image)
      has_cmd isoinfo && cmd=(is9660iso "$2" "$file2") ;;
    archive)
      cmd=(isar "$2" "$file2") ;;
  esac
    [[ -n $cmd && -z $file2 ]] && msg "use ${x}_file${sep}contained_file to view a file in the archive"
    [[ -n $cmd && -n $file2 ]] && file2=
}

analyze_args () {
  # color is set when calling less with -r or -R
  lessarg=`ps -p $PPID -oargs=`
  [[ $lessarg != */less\ * ]] && [[ $lessarg != less\ * ]] && \
  lesspid=`ps -p $PPID -oppid=` && lessarg=`ps -p $lesspid -oargs=`
  [[ $lessarg == *\ +F\ * || $lessarg == *\ : ]] && return 1
  lessarg=`echo $lessarg|sed 's/-[a-zA-Z]*[rR]/-r/'`
  lessarg="$LESS $lessarg"
  if has_cmd tput && [[ $(tput colors) -ge 8 && $lessarg == *-[rR]* ]]; then
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
    cat $2
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
      [[ -z $file2 ]] && has_cmd ishtml && cmd=(ishtml "$2") ;;
    pdf)
      { has_cmd pdftotext && cmd=(istemp pdftotext -nopgbrk -q -- "$2" -); } ||
      { has_cmd pdftohtml && has_cmd ishtml && cmd=(istemp ispdf "$2"); } ||
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
      { has_cmd libreoffice && has_cmd ishtml && cmd=(isoffice "$2" ppt); } ;;
    xlsx)
      { has_cmd in2csv && cmd=(in2csv -f xlsx "$2"); } ||
      { has_cmd xlscat && cmd=(istemp xlscat "$2"); } ||
      { has_cmd excel2csv && cmd=(istemp excel2csv "$2"); } ||
      { has_cmd libreoffice && cmd=(isoffice2 "$2"); } ;;
    odt)
      { has_cmd pandoc && cmd=(pandoc -f odt -t plain "$2"); } ||
      { has_cmd odt2txt && cmd=(istemp odt2txt "$2"); } ||
      { has_cmd libreoffice && cmd=(isoffice2 "$2"); } ;;
    odp)
      { has_cmd libreoffice && has_cmd ishtml && cmd=(isoffice "$2" odp); } ;;
    ods)
      { has_cmd xlscat && t=$t.ods && cat "$2" > $t &&  cmd=(xlscat "$t"); } ||
      { has_cmd libreoffice && has_cmd ishtml && cmd=(isoffice "$2" ods); } ;;
    msword)
      t="$2"; [[ "$t" == - ]] && t=/dev/stdin
      { has_cmd wvText && cmd=(istemp wvText "$t" /dev/stdout); } ||
      { has_cmd antiword && cmd=(antiword "$2"); } ||
      { has_cmd catdoc && cmd=(catdoc "$2"); } ||
      { has_cmd libreoffice && cmd=(isoffice2 "$2"); } ;;
    ms-powerpoint)
      { has_cmd broken_catppt && cmd=(istemp catppt "$2"); } ||
      { has_cmd libreoffice && has_cmd ishtml && cmd=(isoffice "$2" ppt); } ;;
    ms-excel)
      { has_cmd in2csv && cmd=(in2csv -f xls "$2"); } ||
      { has_cmd xls2csv && cmd=(istemp xls2csv "$2"); } ||
      { has_cmd libreoffice && has_cmd ishtml && cmd=(isoffice "$2" xls); } ;;
    ooffice1)
      { has_cmd sxw2txt && cmd=(istemp sxw2txt "$2"); } ||
      { has_cmd libreoffice && cmd=(istemp "libreoffice --headless --cat" "$2"); } ;;
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
      { has_cmd libreoffice && cmd=(istemp "libreoffice --headless --cat" "$2"); } ;;
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
      has_cmd ccze && cat $2 | ccze -A
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
    "${cmd[@]}"
  else
    [[ -n "$file2" ]] && fext=$file2
    [[ -z "$fext" && $fcat == text && $x != plain ]] && fext=$x
    [[ -z "$fext" ]] && fext=$(fileext "$fileext")
    colorizer=$(has_colorizer "$2" "$fext")
    if [[ -n $colorizer && $fcat != binary ]]; then
      $colorizer && return
    fi
    # if fileext set, we need to filter to get rid of .fileext
    [[ -n $fileext || "$2" == - || "$2" == $t ]] && cat "$2"
  fi
}

istar () {
  [[ "$1" =~ ^[a-z_-]*:.* ]] && echo $1: remote operation tar host:file not allowed && return
  if [[ -n $2 ]]; then
    tar Oxf "$1" "$2" 2>&1
  elif [[ $COLOR == *always ]] && has_cmd tarcolor; then
    tar tvf "$1" | tarcolor
  else
    tar tvf "$1"
  fi
}

ispdf () {
  istemp pdftohtml -i -q -s -noframes -nodrm -stdout "$1"|ishtml -
}

isar () {
  if [[ -n $2 ]]; then
    istemp "ar p" $1 $2
  else
    istemp "ar vt" "$1"
  fi
}

iszip () {
  if [[ -n $2 ]]; then
    istemp "unzip -avp" $1 $2
  else
    istemp "unzip -l" "$1"
  fi
}

isrpm () {
  if [[ -z "$2" ]]; then
    istemp "rpm -qivp" "$1"
    [[ $1 == - ]] && set "$t" "$1"
    contentline
    if has_cmd rpm2cpio && has_cmd cpio; then
      rpm2cpio "$1" 2>/dev/null|cpio -i -tv 2>/dev/null
    elif has_cmd rpmunpack && has_cmd cpio; then
      cat "$1" | rpmunpack | gzip -cd | cpio -i --quiet -tv 2>/dev/null
    fi
  elif has_cmd rpm2cpio; then
    rpm2cpio "$1" 2>/dev/null|cpio -i --quiet --to-stdout "$2"
  elif has_cmd rpmunpack; then
    cat "$1" | rpmunpack | gzip -cd | cpio -i --quiet --to-stdout "$2"
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
    else
      istemp ar p "$1" control.tar.gz | gzip -dc - | tar xOf - ./control
    fi
  fi
  data=$(istemp "ar t" "$1"|grep data)
  ft=$(ar p "$1" "$data" | filetype -)
  get_unpack_cmd $ft -
  if [[ -z "$2" ]]; then
    contentline
    istemp "ar p" "$1" "$data" | ${cmd[@]} | tar tvf -
  else
    ar p "$1" "$data" | ${cmd[@]} | tar xOf - "$2"
  fi
}

iscab () {
  if [[ "$1" = - ]]; then
    t=$(nexttmp)
    cat > "$t"
    set "$t" "$2"
  fi
  [[ -z "$2" ]] && cabextract -l "$1" && return
  cabextract -pF "$2" "$1"
}

israr () {
  optz=v
  optn="p -inul"
  prog=$1
  shift
  [[ $prog == bsdtar ]] && optz=tvf && optn=Oxf
  if [[ -z "$2" ]]; then
    istemp "$prog $optz" "$1"
  else
    istemp "$prog $optn" "$1" "$2"
  fi
}

is7zarchive () {
  prog=$1
  if [[ -n "$3" ]]; then
    istemp "$prog e -so" "$2" "$3"
  else
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
  fi
}

is9660iso () {
  if [[ -n "$2" ]]; then
    istemp "isoinfo -i" "$1" "-x$2"
  else
    t="$1"
    istemp "isoinfo -d -i" "$1"
    joliet=$(isoinfo -d -i "$t"| grep -E '^Joliet'|cut -c1)
    contentline
    isoinfo -fR$joliet -i "$t"
  fi
}

isoffice () {
  t=$(nexttmp)
  t2=$t.$2
  cat $1 > $t2
  libreoffice --headless --convert-to html --outdir "$tmpdir" "$t2" > /dev/null 2>&1
  ishtml $t.html
}

isoffice2 () {
  istemp "libreoffice --headless --cat" "$1" 2>/dev/null
}

if has_cmd w3m || has_cmd lynx || has_cmd elinks || has_cmd html2text; then
  ishtml () {
    [[ $1 == - ]] && arg1=-stdin || arg1=$1
    # 4 lines following can easily be reshuffled according to the preferred tool
    has_cmd w3m && nodash "w3m -dump -T text/html" "$1" && return ||
    has_cmd lynx && lynx -force_html -dump "$arg1" && return ||
    has_cmd elinks && nodash "elinks -dump -force-html" "$1" && return ||
    # different incompatible versions with the name html2text may let this fail
	# html2text -utf8  || html2text -from_encoding utf-8
    has_cmd html2text && nodash html2text "$1"
  }
fi

sep=:                       # file name separator
altsep==                    # alternate separator character
if [[ -e "$1" && "$1" == *$sep* ]]; then
  sep=$altsep
elif [[ "$1" == *$altsep* ]]; then
  fn="${1%$altsep*}"
  if [[ -e "$fn" ]]; then
    sep=$altsep
  fi
fi

tmpdir=${TMPDIR:-/tmp}/lesspipe."$RANDOM"
[[ -d "$tmpdir" ]] || mkdir "$tmpdir"
trap "rm -rf '$tmpdir'" EXIT
trap - PIPE

t=$(nexttmp)
analyze_args
# make LESSOPEN="|- ... " work
if [[ $LESSOPEN == *\|-* && $1 == - ]]; then
  cat > $t
  [[ -n $fext ]] && t=$t$sep$fext
  set $1 $t
fi
[[ -d "$tmpdir" ]] || exit 1

IFS=$sep a="$@"
IFS=' '
if [[ "$a" == "" ]]; then
  if [[ "$0" != /* ]]; then
      pat=$(pwd)/
  fi
  if [[ "$SHELL" == *csh ]]; then
    echo "setenv LESSOPEN \"|$pat$0 %s\""
  else
    echo "LESSOPEN=\"|$pat$0 %s\""
    echo "export LESSOPEN"
  fi
else
  show "$a"
fi
