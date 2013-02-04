#!/bin/bash
# lesspipe.sh, a preprocessor for less (version 1.82)
#===============================================================================
### THIS FILE IS GENERATED FROM lesspipe.sh.in, PLEASE GET THE TAR FILE
### from http://sourceforge.net/projects/lesspipe/
### AND RUN configure TO GENERATE A lesspipe.sh THAT WORKS IN YOUR ENVIRONMENT
#===============================================================================
#
# Usage:   lesspipe.sh is called when the environment variable LESSOPEN is set:
#	   LESSOPEN="|lesspipe.sh %s"; export LESSOPEN	(sh like shells)
#	   setenv LESSOPEN "|lesspipe.sh %s"		(csh, tcsh)
#	   Use the fully qualified path if lesspipe.sh is not in the search path
#	   View files in multifile archives:
#			less archive_file:contained_file
#	   This can be used to extract ASCII files from a multifile archive:
#			less archive_file:contained_file>extracted_file
#	   As less is not good for extracting raw data use instead:
#			lesspipe.sh archive_file:contained_file>extracted_file
#          Even a file in a multifile archive that itself is contained in yet
#          another archive can be viewed this way:
#			less super_archive:archive_file:contained_file
#	   Display the last file in the file1:..:fileN chain in raw format:
#	   Suppress input filtering:	less file1:..:fileN:   (append a colon)
#	   Suppress decompression:	less file1:..:fileN::  (append 2 colons)
#
# Required programs and supported formats: see the separate file README
# License: GPL (see file LICENSE)
# History: see the separate file ChangeLog
# Author:  Wolfgang Friebel, DESY (Wolfgang.Friebel AT desy.de)
#
#===============================================================================
( [[ -n 1 && -n 2 ]] ) > /dev/null 2>&1 || exec zsh -y --ksh-arrays -- "$0" ${1+"$@"}
#setopt KSH_ARRAYS SH_WORD_SPLIT 2>/dev/null
set +o noclobber
tarcmd='tar'

dir=${LESSOPEN#\|}
dir=${dir%%lesspipe.sh*\%s}
dir=${dir%%/}
PATH=$PATH:$dir

cmd_exist () {
  command -v "$1" > /dev/null 2>&1 && return 0 || return 1
}

filecmd() {
  file -L -s "$@"
  file -L -s -i "$@" 2> /dev/null | sed -n 's/.*charset=/;/p' | tr a-z A-Z
}

sep=:						# file name separator
altsep==					# alternate separator character
if [[ -f "$1" && "$1" = *$sep* || "$1" = *$altsep ]]; then
  sep=$altsep
  xxx="${1%=}"
  set "$xxx"
fi
if cmd_exist mktemp; then
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/lesspipe.XXXXXXXXXX")

  nexttmp () {
    # nexttmp -d returns a directory
    mktemp $1 "${tmpdir}/XXXXXXXX"
  }
else
  tmpdir=${TMPDIR:-/tmp}/lesspipe.$RANDOM
  mkdir $tmpdir

  nexttmp () {
    new="$tmpdir/lesspipe.$RANDOM"
    [[ "$1" = -d ]] && mkdir $new
    echo $new
  }
fi
[[ -d "$tmpdir" ]] || exit 1
trap "rm -rf '$tmpdir'" 0
trap - PIPE

unset iconv
iconv() {
  if [[ -z "$iconv" ]]; then
    arg=$(printf "%s$(command iconv --help 2>/dev/null | \
      sed -n 's/.*\(--.*-subst=\)\(FORMATSTRING\).*/\1\\033[7m?\\033[m/p' | \
      tr \\n ' ')")
    if [[ -n "$arg" ]]; then
      iconv="command iconv -c $arg  -t //TRANSLIT"
    else
      iconv="command iconv -c"
    fi
  fi
  if $iconv "$@" > /dev/null 2>&1; then
    msg "append $sep to filename to view the $2 encoded data"
    $iconv "$@"
  fi
}

msg () {
  if [[ -n "$LESSQUIET" ]]; then
    return
  fi
  echo "==> $@"
}

filetype () {
  # wrapper for 'file' command
  typeset name
  name="$1"
  if [[ "$1" = - ]]; then
    dd bs=40000 count=1 > "$tmpdir/file" 2>/dev/null
    set "$tmpdir/file" "$2"
    name="$filen"
  fi
  typeset type
  # type=" $(filecmd -b "$1")" # not supported by all versions of 'file'
  type=$(filecmd "$1" | cut -d : -f 2-)
  if [[ "$type" = " empty" ]]; then
    # exit if file returns "empty" (e.g., with "less archive:nonexisting_file")
    exit 1
  elif [[ "$type" = *XML* && "$name" = *html ]]; then
    type=" HTML document text"
  elif [[ ("$type" = *HTML* || "$type" = *ASCII*) && "$name" = *xml ]]; then
    type=" XML document text"
  elif [[ "$type" != *lzip\ compressed* && ("$name" = *.lzma || "$name" = *.tlz) ]]; then
    type=" LZMA compressed data"
  elif [[ ("$type" = *Zip* || "$type" = *ZIP*) && ("$name" = *.jar || "$name" = *.xpi) ]]; then
    type=" Zip compressed Jar archive"
  elif [[ "$type" = *Microsoft\ Office\ Document* && ("$name" = *.ppt) ]]; then
       type=" PowerPoint document"
  elif [[ "$type" = *Microsoft\ Office\ Document* && ("$name" = *.xls) ]]; then
       type=" Excel document"
  fi
  echo "$type"
}

show () {
  file1="${1%%$sep*}"
  rest1="${1#$file1}"
  while [[ "$rest1" = ::* ]]; do
    if [[ "$rest1" = "::" ]]; then
      break
    else
      rest1="${rest1#$sep$sep}"
      file1="${rest1%%$sep*}"
      rest1="${rest1#$file1}"
      file1="${1%$rest1}"
    fi
  done
  rest11="${rest1#$sep}"
  file2="${rest11%%$sep*}"
  rest2="${rest11#$file2}"
  while [[ "$rest2" = ::* ]]; do
    if [[ "$rest2" = "::" ]]; then
      break
    else
      rest2="${rest2#$sep$sep}"
      file2="${rest2%%$sep*}"
      rest2="${rest2#$file2}"
      file2="${rest11%$rest2}"
    fi
  done
  if [[ "$file2" != "" ]]; then
    in_file="-i$file2"
  fi
  rest2="${rest11#$file2}"
  rest11="$rest1"
  if [[ "$cmd" = "" ]]; then
    type=$(filetype "$file1") || exit 1
    get_cmd "$type" "$file1" "$rest1"
    if [[ "$cmd" != "" ]]; then
      show "-$rest1"
    else
      isfinal "$type" "$file1" "$rest11"
    fi
  elif [[ "$c1" = "" ]]; then
    c1=("${cmd[@]}")
    type=$("${c1[@]}" | filetype -) || exit 1
    get_cmd "$type" "$file1" "$rest1"
    if [[ "$cmd" != "" ]]; then
      show "-$rest1"
    else
      "${c1[@]}" | isfinal "$type" - "$rest11"
    fi
  elif [[ "$c2" = "" ]]; then
    c2=("${cmd[@]}")
    type=$("${c1[@]}" | "${c2[@]}" | filetype -) || exit 1
    get_cmd "$type" "$file1" "$rest1"
    if [[ "$cmd" != "" ]]; then
      show "-$rest1"
    else
      "${c1[@]}" | "${c2[@]}" | isfinal "$type" - "$rest11"
    fi
  elif [[ "$c3" = "" ]]; then
    c3=("${cmd[@]}")
    type=$("${c1[@]}" | "${c2[@]}" | "${c3[@]}" | filetype -) || exit 1
    get_cmd "$type" "$file1" "$rest1"
    if [[ "$cmd" != "" ]]; then
      show "-$rest1"
    else
      "${c1[@]}" | "${c2[@]}" | "${c3[@]}" | isfinal "$type" - "$rest11"
    fi
  elif [[ "$c4" = "" ]]; then
    c4=("${cmd[@]}")
    type=$("${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | filetype -) || exit 1
    get_cmd "$type" "$file1" "$rest1"
    if [[ "$cmd" != "" ]]; then
      show "-$rest1"
    else
      "${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | isfinal "$type" - "$rest11"
    fi
  elif [[ "$c5" = "" ]]; then
    c5=("${cmd[@]}")
    type=$("${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | "${c5[@]}" | filetype -) || exit 1
    get_cmd "$type" "$file1" "$rest1"
    if [[ "$cmd" != "" ]]; then
      echo "$0: Too many levels of encapsulation"
    else
      "${c1[@]}" | "${c2[@]}" | "${c3[@]}" | "${c4[@]}" | "${c5[@]}" | isfinal "$type" - "$rest11"
    fi
  fi
}

get_cmd () {
  cmd=
  typeset t
  if [[ "$1" = *[bg]zip*compress* || "$1" = *compress\'d\ * || "$1" = *packed\ data* || "$1" = *LZMA\ compressed* || "$1" = *lzip\ compressed* || "$1" = *[Xx][Zz]\ compressed* ]]; then ## added '#..then' to fix vim's syntax parsing
    if [[ "$3" = $sep$sep ]]; then
      return
    elif [[ "$1" = *bzip*compress* ]] && cmd_exist bzip2; then
      cmd=(bzip2 -cd "$2")
      if [[ "$2" != - ]]; then filen="$2"; fi
      case "$filen" in
        *.bz2) filen="${filen%.bz2}";;
        *.tbz) filen="${filen%.tbz}.tar";;
      esac
      return
    elif [[ "$1" = *LZMA\ compressed* ]] && cmd_exist lzma; then
      cmd=(lzma -cd "$2")
      if [[ "$2" != - ]]; then filen="$2"; fi
      case "$filen" in
        *.lzma) filen="${filen%.lzma}";;
        *.tlz) filen="${filen%.tlz}.tar";;
      esac
    elif [[ "$1" = *gzip\ compress* || "$1" =  *compress\'d\ * || "$1" = *packed\ data* ]]; then ## added '#..then' to fix vim's syntax parsing
      cmd=(gzip -cd "$2")
      if [[ "$2" != - ]]; then filen="$2"; fi
      case "$filen" in
        *.gz) filen="${filen%.gz}";;
        *.tgz) filen="${filen%.tgz}.tar";;
      esac
    elif [[ "$1" = *[Xx][Zz]\ compressed* ]] && cmd_exist xz; then
      cmd=(xz -cd "$2")
      if [[ "$2" != - ]]; then filen="$2"; fi
      case "$filen" in
       *.xz) filen="${filen%.xz}";;
       *.txz) filen="${filen%.txz}.tar";;
      esac
    fi
    return
  fi

  rsave="$rest1"
  rest1="$rest2"
  if [[ "$file2" != "" ]]; then
    if [[ "$1" = *\ tar* || "$1" = *\	tar* ]]; then
      cmd=(istar "$2" "$file2")
    elif [[ "$1" = *Debian* ]]; then
      t=$(nexttmp)
      if [[ "$file2" = control/* ]]; then
        istemp "ar p" "$2" control.tar.gz | gzip -dc - > "$t"
        file2=".${file2:7}"
      else
        istemp "ar p" "$2" data.tar.gz | gzip -dc - > "$t"
      fi
      cmd=(istar "$t" "$file2")
    elif [[ "$1" = *RPM* ]] && cmd_exist cpio && ( cmd_exist rpm2cpio || cmd_exist rpmunpack ); then
      cmd=(isrpm "$2" "$file2")
    elif [[ "$1" = *Zip* || "$1" = *ZIP* ]] && cmd_exist unzip; then
      cmd=(istemp "unzip -avp" "$2" "$file2")
    elif [[ "$1" = *RAR\ archive* ]]; then
      if cmd_exist unrar; then
        cmd=(istemp "unrar p -inul" "$2" "$file2")
      elif cmd_exist rar; then
        cmd=(istemp "rar p -inul" "$2" "$file2")
      fi
    elif [[ "$1" = *7-zip\ archive* || "$1" = *7z\ archive* ]] && cmd_exist 7za; then
      cmd=(istemp "7za e -so" "$2" "$file2")
    elif [[ "$1" = *7-zip\ archive* || "$1" = *7z\ archive* ]] && cmd_exist 7zr; then
      cmd=(istemp "7zr e -so" "$2" "$file2")
    elif [[ "$1" = *[Cc]abinet* ]] && cmd_exist cabextract; then
      cmd=(iscab "$2" "$file2")
    elif [[ "$1" = *\ ar\ archive* ]]; then
      cmd=(istemp "ar p" "$2" "$file2")
    elif [[ "$1" = *ISO\ 9660* ]] && cmd_exist isoinfo; then
      cmd=(isoinfo "-i$2" "-x$file2")
    fi
    if [[ "$cmd" != "" ]]; then
      filen="$file2"
    fi
  fi
}

iscab () {
  typeset t
  if [[ "$1" = - ]]; then
    t=$(nexttmp)
    cat > "$t"
    set "$t" "$2"
  fi
  cabextract -pF "$2" "$1"
}

istar () {
  $tarcmd Oxf "$1" "$2" 2>/dev/null
}

isdvi () {
  typeset t
  if [[ "$1" != *.dvi ]]; then
    t="$tmpdir/tmp.dvi"
    cat "$1" > "$t"
    set "$t"
  fi
  dvi2tty -q "$1"
}

istemp () {
  typeset prog
  typeset t
  prog="$1"
  t="$2"
  shift
  shift
  if [[ "$t" = - ]]; then
    t=$(nexttmp)
    cat > "$t"
  fi
  if [[ $# -gt 0 ]]; then
    $prog "$t" "$@" 2>/dev/null
  else
    $prog "$t" 2>/dev/null
  fi
}

nodash () {
  typeset prog
  prog="$1"
  shift
  if [[ "$1" = - ]]; then
    shift
    if [[ $# -gt 0 ]]; then
      $prog "$@" 2>/dev/null
    else
      $prog 2>/dev/null
    fi
  else
    $prog "$@" 2>/dev/null
  fi
}

isrpm () {
  if cmd_exist rpm2cpio && cmd_exist cpio; then
    typeset t
    if [[ "$1" = - ]]; then
      t=$(nexttmp)
      cat > "$t"
      set "$t" "$2"
    fi
    # setup $b as a batch file containing "$b.out"
    typeset b
    b=$(nexttmp)
    echo "$b.out" > "$b"
    # to support older versions of cpio the --to-stdout option is not used here
    rpm2cpio "$1" 2>/dev/null|cpio -i --quiet --rename-batch-file "$b" "$2"
    cat "$b.out"
  elif cmd_exist rpmunpack && cmd_exist cpio; then
    # rpmunpack will write to stdout if it gets file from stdin
    # extract file $2 from archive $1, assume that cpio is sufficiently new
    # (option --to-stdout existing) if rpmunpack is installed
    cat "$1" | rpmunpack | gzip -cd | cpio -i --quiet --to-stdout "$2"
  fi
}


if cmd_exist html2text || cmd_exist elinks || cmd_exist links || cmd_exist lynx || cmd_exist w3m; then
  PARSEHTML=yes
else
  PARSEHTML=no
fi
#parsexml () { nodash "elinks -dump -default-mime-type text/xml" "$1"; }
parsehtml () {
  if [[ "$PARSEHTML" = no ]]; then
    msg "No suitable tool for HTML parsing found, install one of html2text, elinks, links, lynx or w3m"
    return
  elif cmd_exist html2text; then
    html2text -style pretty "$1"
  elif cmd_exist lynx; then
    if [[ "$1" = - ]]; then set - -stdin; fi
    lynx -dump -force_html "$1" && return
  elif cmd_exist w3m; then
    nodash "w3m -dump -T text/html" "$1"
  elif cmd_exist elinks; then
    nodash "elinks -dump -force-html" "$1"
  elif cmd_exist links; then
    if [[ "$1" = - ]]; then set - -stdin; fi
    links -dump -force_html "$1"
  fi
}

isfinal() {
  typeset t
  if [[ "$3" = $sep$sep ]]; then
    cat "$2"
    return
  elif [[ "$3" = $sep* ]]; then
    if [[ "$3" = $sep ]]; then
      msg "append :. or :<filetype> to activate syntax highlighting"
    else
      lang=${3#$sep}
      lang="-l ${lang#.}"
      lang=${lang%%-l }
      if cmd_exist code2color; then
        code2color $PPID ${in_file:+"$in_file"} $lang "$2"
        if [[ $? = 0 ]]; then
          return
        fi
      fi
    fi
    cat "$2"
    return
  fi

  # color requires -r or -R when calling less
  typeset COLOR
  if [[ $(tput colors) -ge 8 && ("$LESS" = *-*r* || "$LESS" = *-*R*) ]]; then
    COLOR="--color=always"
  fi

  if [[ "$1" = *No\ such* ]]; then
    exit 1
  elif [[ "$1" = *directory* ]]; then
    cmd=(ls -lA $COLOR "$2")
    if ! ls $COLOR > /dev/null 2>&1; then
      cmd=(ls -lA -G "$2")
      if ! ls -lA -G > /dev/null 2>&1; then
        cmd=(ls -lA "$2")
      fi
    fi
    msg "This is a directory, showing the output of ${cmd[@]}"
    if [[ ${cmd[2]} = '-G' ]]; then
      CLICOLOR_FORCE=1 "${cmd[@]}"
    else
      "${cmd[@]}"
    fi
  elif [[ "$1" = *\ tar* || "$1" = *\	tar* ]]; then
    msg "use tar_file${sep}contained_file to view a file in the archive"
    if [[ -n $COLOR ]] && cmd_exist tarcolor; then
      $tarcmd tvf "$2" | tarcolor
    else
      $tarcmd tvf "$2"
    fi
  elif [[ "$1" = *RPM* ]]; then
    header="use RPM_file${sep}contained_file to view a file in the RPM"
    if cmd_exist rpm; then
      echo $header
      istemp "rpm -qivp" "$2"
      header="";
    fi
    if cmd_exist cpio && cmd_exist rpm2cpio; then
      echo $header
      echo "================================= Content ======================================"
      istemp rpm2cpio "$2" 2>/dev/null|cpio -i -tv 2>/dev/null
    elif cmd_exist cpio && cmd_exist rpmunpack; then
      echo $header
      echo "================================= Content ======================================"
      cat "$2" | rpmunpack | gzip -cd | cpio -i -tv 2>/dev/null
    else
      msg "please install rpm2cpio or rpmunpack to see the contents of RPM files"
    fi
  elif [[ "$1" = *roff* ]] && cmd_exist groff; then
    DEV=utf8
    if [[ $LANG != *UTF*8* && $LANG != *utf*8* ]]; then
      if [[ "$LANG" = ja* ]]; then
        DEV=nippon
      else
        DEV=latin1
      fi
    fi
    MACRO=andoc
    if [[ "$2" = *.me ]]; then
      MACRO=e
    elif [[ "$2" = *.ms ]]; then
      MACRO=s
    fi
    msg "append $sep to filename to view the nroff source"
    groff -s -p -t -e -T$DEV -m$MACRO "$2"
  elif [[ "$1" = *Debian* ]]; then
    msg "use Deb_file${sep}contained_file to view a file in the Deb"
    if cmd_exist dpkg; then
      nodash "dpkg -I" "$2"
    else
      echo
      istemp "ar p" "$2" control.tar.gz | gzip -dc - | $tarcmd tvf - | sed -r 's/(.{48})\./\1control/'
    fi
    echo
    istemp "ar p" "$2" data.tar.gz | gzip -dc - | $tarcmd tvf -
  # do not display all perl text containing pod using perldoc
  #elif [[ "$1" = *Perl\ POD\ document\ text* || "$1" = *Perl5\ module\ source\ text* ]]; then
  elif [[ "$1" = *Perl\ POD\ document\ text* ]] && cmd_exist perldoc; then
    msg "append $sep to filename to view the perl source"
    istemp perldoc "$2"
  elif [[ "$1" = *\ script* ]]; then
    set "plain text" "$2"
  elif [[ "$1" = *text\ executable* ]]; then
    set "plain text" "$2"
  elif [[ "$1" = *PostScript* ]]; then
    if cmd_exist pstotext; then
      msg "append $sep to filename to view the postscript file"
      nodash pstotext "$2"
    elif cmd_exist ps2ascii; then
      msg "append $sep to filename to view the postscript file"
      istemp ps2ascii "$2"
    else
      msg "install pstotext or ps2ascii to view a textual representation of the file contents"
    fi
  elif [[ "$1" = *executable* ]]; then
    msg "append $sep to filename to view the raw file"
    nodash strings "$2"
  elif [[ "$1" = *\ ar\ archive* ]]; then
    msg "use library${sep}contained_file to view a file in the archive"
    istemp "ar vt" "$2"
  elif [[ "$1" = *shared* ]] && cmd_exist nm; then
    msg "This is a dynamic library, showing the output of nm"
    istemp nm "$2"
  elif [[ "$1" = *Zip* || "$1" = *ZIP* ]] && cmd_exist unzip; then
    msg "use zip_file${sep}contained_file to view a file in the archive"
    istemp "unzip -lv" "$2"
  elif [[ "$1" = *RAR\ archive* ]]; then
    if cmd_exist unrar; then
      msg "use rar_file${sep}contained_file to view a file in the archive"
      istemp "unrar v" "$2"
    elif cmd_exist rar; then
      msg "use rar_file${sep}contained_file to view a file in the archive"
      istemp "rar v" "$2"
    fi 
  elif [[ "$1" = *7-zip\ archive* || "$1" = *7z\ archive* ]] && cmd_exist 7za; then
    typeset res
    res=$(istemp "7za l" "$2")
    if [[ "$res" = *\ 1\ file* ]]; then
      msg "a 7za archive containing one file was silently unpacked"
      if [[ "$2" != - ]]; then
        7za e -so "$2" 2>/dev/null
      else
        # extract name of temporary file containing the 7za archive
        t=${res#*Listing\ archive:\ }
        t2="
"
        t=${t%%$t2*}
        7za e -so $t 2>/dev/null
      fi
    else
      msg "use 7za_file${sep}contained_file to view a file in the archive"
      echo "$res"
    fi
  elif [[ "$1" = *7-zip\ archive* || "$1" = *7z\ archive* ]] && cmd_exist 7zr; then
    typeset res
    res=$(istemp "7zr l" "$2")
    if [[ "$res" = *\ 1\ file* ]]; then
      msg "a 7za archive containing one file was silently unpacked"
      if [[ "$2" != - ]]; then
        7zr e -so "$2" 2>/dev/null
      else
        # extract name of temporary file containing the 7za archive
        t=${res#*Listing\ archive:\ }
        t2="
"
        t=${t%%$t2*}
        7zr e -so $t 2>/dev/null
      fi
    else
      msg "use 7za_file${sep}contained_file to view a file in the archive"
      echo "$res"
    fi
  elif [[ "$1" = *[Cc]abinet* ]] && cmd_exist cabextract; then
    msg "use cab_file${sep}contained_file to view a file in the cabinet"
    istemp "cabextract -l" "$2"
  elif [[ "$1" = *\ DVI* ]] && cmd_exist dvi2tty; then
    msg "append $sep to filename to view the raw DVI file"
    isdvi "$2"
  elif [[ "$PARSEHTML" = yes && "$1" = *HTML* ]]; then
    msg "append $sep to filename to view the HTML source"
    parsehtml "$2"
  elif [[ "$PARSEHTML" = yes && "$1" = *PDF* ]] && cmd_exist pdftohtml; then
    msg "append $sep to filename to view the PDF source"
    t=$(nexttmp)
    cat "$2" > "$t"; pdftohtml -stdout "$t" | parsehtml -
  elif [[ "$1" = *PDF* ]] && cmd_exist pdftotext; then
    msg "append $sep to filename to view the PDF source"
    istemp pdftotext "$2" -
  elif [[ "$1" = *DjVu* ]] && cmd_exist djvutxt; then
    msg "append $sep to filename to view the DjVu source"
    djvutxt "$2"
  elif [[ "$1" = *Microsoft\ Word* || "$1" = *Microsoft\ Office* ]]; then
    if cmd_exist antiword; then
      msg "append $sep to filename to view the raw word document"
      antiword "$2"
    elif cmd_exist catdoc; then
      msg "append $sep to filename to view the raw word document"
      catdoc "$2"
    else
      msg "install antiword or catdoc to view human readable text"
      cat "$2"
    fi
  elif [[ "$1" = *Rich\ Text\ Format* ]]  && cmd_exist unrtf; then
    if [[ "$PARSEHTML" = yes ]]; then
      msg "append $sep to filename to view the RTF source"
      istemp "unrtf --html" "$2" | parsehtml -
    else
      msg "append $sep to filename to view the RTF source"
      istemp "unrtf --text" "$2" | sed -e "s/^### .*//" | fmt -s
    fi
  elif [[ "$PARSEHTML" = yes && "$1" = *Excel\ document* ]] && cmd_exist xlhtml; then
    msg "append $sep to filename to view the spreadsheet source"
    xlhtml -te "$2" | parsehtml -
  elif [[ "$PARSEHTML" = yes && "$1" = *PowerPoint\ document* ]] && cmd_exist ppthtml; then
    msg "append $sep to filename to view the PowerPoint source"
    ppthtml "$2" | parsehtml -
  elif [[ "$PARSEHTML" = yes && ("$1" = *OpenDocument\ [CHMPST]* || "$1" = *OpenOffice\.org\ 1\.x\ [CIWdgpst]*) ]] && cmd_exist unzip; then
    if cmd_exist o3tohtml; then
      msg "append $sep to filename to view the OpenOffice or OpenDocument source"
      istemp "unzip -avp" "$2" content.xml | o3tohtml | parsehtml -
    elif cmd_exist sxw2txt; then
      msg "append $sep to filename to view the OpenOffice or OpenDocument source"
      istemp sxw2txt "$2"
    else
      msg "install at least sxw2txt from the lesspipe package to see plain text in openoffice documents"
    fi
  elif [[ "$1" = *ISO\ 9660* ]] && cmd_exist isoinfo; then
    if [[ "$2" != - ]]; then
      msg "append $sep to filename to view the raw data"
      isoinfo -d -i "$2"
      joliet=`isoinfo -d -i "$2" | egrep '^Joliet'|cut -c1`
      echo "================================= Content ======================================"
      isoinfo -lR$joliet -i "$2"
    fi
  elif [[ "$1" = *image\ data*  || "$1" = *JPEG\ file* || "$1" = *JPG\ file* ]] && cmd_exist identify; then
    msg "append $sep to filename to view the raw data"
    identify -verbose "$2"
  elif [[ "$1" = *MPEG\ *layer\ 3\ audio* || "$1" = *MPEG\ *layer\ III* || "$1" = *mp3\ file* || "$1" = *MP3* ]]; then
    if cmd_exist id3v2; then
      msg "append $sep to filename to view the raw data"
      istemp "id3v2 -l" "$2"
    elif cmd_exist mp3info2; then
      msg "append $sep to filename to view the raw data"
      mp3info2 "$2"
    elif cmd_exist mp3info; then
      msg "append $sep to filename to view the raw data"
      mp3info "$2"
    fi
  elif [[ "$1" = *perl\ Storable* ]]; then
    msg "append $sep to filename to view the raw data"
    perl -MStorable=retrieve -MData::Dumper -e '$Data::Dumper::Indent=1;print Dumper retrieve shift' "$2"
  elif [[ "$1" = *UTF-8* && $LANG != *UTF-8 ]] && cmd_exist iconv; then
    iconv -f UTF-8 "$2"
  elif [[ "$1" = *ISO-8859* && $LANG != *ISO-8859-1 ]] && cmd_exist iconv; then
    iconv -f ISO-8859-1 "$2"
  elif [[ "$1" = *UTF-16* && $LANG != *UTF-16 ]] && cmd_exist iconv; then
    iconv -f UTF-16 "$2"
  elif [[ "$1" = *GPG\ encrypted\ data* ]] && cmd_exist gpg; then
    msg "append $sep to filename to view the encrypted file"
    gpg -d "$2"
  elif [[ "$1" = *data* ]]; then
    msg "append $sep to filename to view the raw data"
    nodash strings "$2"
  else
    set "plain text" "$2"
  fi
  if [[ "$1" = *plain\ text* ]]; then
    if cmd_exist code2color; then
      code2color $PPID ${in_file:+"$in_file"} "$2"
      if [[ $? = 0 ]]; then
        return
      fi
    fi
  fi
  if [[ "$2" = - ]]; then
    cat
  fi  
}

IFS=$sep a="$@"
IFS=' '
if [[ "$a" = "" ]]; then
  if [[ "$0" != /* ]]; then
     pat=`pwd`/
  fi
  if [[ "$SHELL" = *csh ]]; then
    echo "setenv LESSOPEN \"|$pat$0 %s\""
  else
    echo "LESSOPEN=\"|$pat$0 %s\""
    echo "export LESSOPEN"
  fi
else
  # check for pipes so that "less -f ... <(cmd) ..." works properly
  [[ -p "$1" ]] && exit 1
  show "$a"
fi
