# lesspipe.sh, a preprocessor for less

Version: 2.02
Author : Wolfgang Friebel [wp.friebel@gmail.com](mailto://wp.friebel@gmail.com)
License: GPL

Latest version available as:
 [zip file on github](https://github.com/wofr06/lesspipe.sh/archive/lesspipe.zip)
 [repository on github](https://github.com/wofr06/lesspipe)

The development version can be cloned using git:
 `git clone https://github.com/wofr06/lesspipe.git`
To report bugs or make proposals to improve lesspipe please contact
the author by email.

## Contents

 0. Motivation
 1. Introduction
 2. Usage
 3. Required programs
 4. Supported file formats
    - Supported compression methods and archive formats
    - List of preprocessed file types
    - Conversion of files with alternate character encoding
 5. Colorizing the output
    - Syntax highlighting
      - Syntax highlighting choices
      - List of supported languages
    - Colored Directory listing
    - Colored listing of tar file contents
 6. Calling less from standard input
 7. Displaying files with special characters in the file name
 8. Tab completion for zsh and bash
 9. User defined filtering
 10. (Old) documentation about lesspipe
 11. External links
    -   URLs to some utilities
    -  References
 12. Contributors

## 0. Motivation

 If you use

 - the pager `less` in the command line,
 - the version control system `git`,
 - the text editor `Vim` or
 - the mail client `mutt`,

 then lesspipe.sh enables these programs to *read* non-text files, such as:

 - PDFs,
 - (Microsoft or LibreOffice) Office documents, or even
 - media (such as JPG or PNG images, MP3 audio or video) files

 where *read* means,

 - (format and) show the contained text (of a document or tag in a media file),
   or
 - show sensible file information (such as length of the video).

 To enable `less` respectively `git`, `Vim` or `mutt` to read non-text files by
 lesspipe.sh, see

 - Section 2 on the Usage of lesspipe.sh, respectively
 - the Wiki at https://github.com/wofr06/lesspipe/wiki

  For the text and info extraction, lesspipe.sh will depend on external tools,
  but many use cases are covered by an installation of

  - LibreOffice and a common text browser (such as `lynx`),
  - pdftotext, and
  - mediainfo (or exiftool).

## 1. Introduction

 To browse files under UNIX the excellent viewer less [1] can be used. By
 setting the environment variable **LESSOPEN**, less can be enhanced by external
 filters to become even more powerful. Most Linux distributions come already
 with a "lesspipe.sh" that covers the most common situations.

 The input filter for less described here is called "lesspipe.sh". It is able
 to process a wide variety of file formats. It enables users to deeply inspect
 archives and to display the contents of files in archives without having to
 unpack them before. That means file contents can be properly interpreted even
 if the files are compressed and contained in a hierarchy of archives (often
 found in RPM or DEB archives containing source tarballs). The filter is easily
 extensible for new formats.

 The input filter which is also called "lesspipe.sh" is a bash script, but
 works as well as a zsh script.

 The filter does different things depending on the file format. In most cases
 it is determined on the output of the `file --mime` command [2], [6], that
 returns the mime type. In some cases the mime type is to unspecific and then
 the `file` command yielding a textual description or the file suffix is used
 to determine what to display.

## 2. Usage

 (see also the man page lesspipe.1)

 To activate lesspipe.sh the environment variable **LESSOPEN** has to be defined
 in the following way:
```
        LESSOPEN="|lesspipe.sh %s"; export LESSOPEN  # (sh like shells)
        setenv LESSOPEN "|lesspipe.sh %s"            # (csh, tcsh)
```
 If `lesspipe.sh` is not in the UNIX search path or if the wrong `lesspipe.sh` is
 found in the search path, then the full path to `lesspipe.sh` should be given
 in the above commands.

 The command to set **LESSOPEN** can also be displayed by calling `lesspipe.sh`
 without arguments. This can even be used to set **LESSOPEN** directly:
```
        eval lesspipe.sh                  # (bash) or
        lesspipe.sh | source /dev/stdin   # (zsh)
```
 As `lesspipe.sh` is accepting only a single argument, a hierarchical list of file
 names has to be separated by a non blank character. A colon is rarely found
 in file names, therefore it has been chosen as the separator character. If a
 file name does however contain at least one isolated colon, the equal sign =
 can be used as an alternate separator character. At each stage in
 extracting files from such a hierarchy the file type is determined. This
 guarantees a correct processing and display at each stage of the filtering.

 To view files in multifile archives the following command can be used:
```
        less archive_file:contained_file
```
 This can be used to extract single files from a multifile archive:
```
        less archive_file:contained_file > extracted_file
```
 For extracting files less is not required, that can be done also using:
```
        lesspipe.sh archive_file:contained_file > extracted_file
```
 Even a file in a multifile archive that itself is contained in yet
 another archive can be viewed this way:
```
        less super_archive:archive_file:contained_file
```
 The script is able to extract files up to a depth of 6 where applying a
 decompression algorithm counts as a separate level. In a few rare cases the
 file command does not recognize the correct format.
 In such cases the filtering can be suppressed by a trailing colon on the file
 name. That can also be used to output the original unmodified file or to
 suppress syntax highlighting (see below).

 Several environment variables can influence the behavior of lesspipe.sh.

 **LESSQUIET** will suppress additional output not belonging to the file contents
 if set to a non empty value.

 **LESS** can be used to switch on colored less output (should contain -R).

 **LESSCOLORIZER** can be set to prefer a highlighting program from the following
 choices (`bat` `batcat` `pygmentize` `source-highlight` `code2color` `vimcolor`).
 Otherwise the first program in that list that is installed will be used.

## 3. Required programs

 Most of the programs are checked for its existence before they get called
 in lesspipe.sh. However some of the programs are assumed to always be
 installed. That is foremost `bash` or `zsh` (have the appropriate first line
 in the script), then `file` and other utilities like `cat`, `dd`,
 `grep`, `gzip`, `ln`, `ls`, `mkdir`, `rm`, `sed`, `strings` and `tar`.
 For testing and configuring lesspipe.sh `perl` is used, that is however not
 required in just using `lesspipe.sh`

## 4. Supported file formats

 Currently `lesspipe.sh` [3] supports the following compression methods
 and file types (i.e. the file contents gets transformed by `lesspipe.sh`):

### 4.1 Supported compression methods and archive formats
- gzip, compress	requires `gzip`
- bzip2			requires `bzip2`
- lzma			requires `lzma`
- xz			requires `xz`
- zstd			requires `zstd`
- brotli		requires `bro`
- lz4			requires `lz4`
- tar			requires optionally `archive_color` for coloring
- ar library		requires `bsdtar` or `ar`
- zip archive		requires `bsdtar` or `unzip`
- jar archive		requires `bsdtar` or `unzip`
- rar archive		requires `bsdtar` or `unrar or `rar`
- 7-zip archive		requires `7zr`
- lzip archive		requires `lzip`
- iso images		requires `bsdtar` or `isoinfo`
- rpm			requires `rpm2cpio` and `cpio` or `bsdtar`
- Debian		requires `bsdtar` or `ar`
- cab			requires `cabextract`

### 4.2 List of preprocessed file types
- directory		displayed using `ls -lA`
- nroff(man)		requires `groff`
- shared library	requires `nm`
- MS Word (doc)		requires `wvText` or `antiword` or `catdoc` or `libreoffice`
- Powerpoint (ppt)	requires `catppt`
- Excel (xls)		requires `in2csv` (csvkit) or `xls2csv`
- odt			requires `pandoc` or `odt2txt` or `libreoffice`
- odp			requires `libreoffice`
- ods			requires `xlscat` or `libreoffice`
- MS Word (docx)	requires `pandoc` or `docx2txt` or `libreoffice`
- Powerpoint (pptx)	requires `pptx2md` or `libreoffice`
- Excel (xlsx)		requires `in2csv` or `xlscat` or `excel2csv` or `libreoffice`
- rtf			requires `unrtf` or `libreoffice`
- epub			requires `pandoc`
- html,xml		requires `w3m` or `lynx` or `elinks` or `html2text`
- pdf			requires `pdftotext` or `pdftohtml`
- perl pod		requires `pod2text` or `perldoc`
- perl storable		requires perl (and the modules Storable and Data::Dumper)
- dvi			requires `dvi2tty`
- djvu			requires `djvutxt`
- ps			requires `ps2ascii` (from the gs package)
- mp3			requires `id3v2`
- multimedia formats	requires `mediainfo` or `exiftools`
- image formats		requires `mediainfo` or `exiftools` or `identify`
- hdf, nc4		requires `h5dump` or `ncdump` (NetCDF format)
- crt, pem, csr, crl	requires `openssl`
- matlab		requires `matdump`
- Jupyter notebook	requires `pandoc`
- markdown		requires `mdcat` or `pandoc`
- log			requires `ccze`
- java.class		requires `procyon`
- MacOS X plist		requires `plistutil`
- binary data		requires `strings`

To show the unmodified html, xml or perl pod text append a colon to the file
name. Appending in addition the file type (html, xml, pod) produces a colored
output if the conditions for colorizing (see below) are met.

### 4.3 Conversion of files with alternate character encoding
 If the file utility reports text with an encoding different from the one
 used in the terminal then the text will be transformed using `iconv` into
 the default encoding. This does assume the file command gets the file
 encoding right, which can be wrong in some situations. An appended colon
 to the file name does suppress the conversion.

## 5. Colorizing the output

 Syntax highlighting and other methods of colorizing the output
 is only activated if the environment variable **LESS** is existing and contains
 the option -R (or -r) or less is called with one of these options.

 The display of wrapped long lines and moving backward in a file using the
 option -r can give weird output and is not recommended. For an explanation see
 http://www.greenwoodsoftware.com/less/faq.html#dashr

### 5.1 Syntax highlighting
 Syntax highlighting is not always wanted, it can be switched off by
 appending a colon after the file name if the output was colorful. If the
 wrong language was chosen for syntax highlighting then another one can be
 forced by appending a colon and a suffix to the file name as follows (assuming
 this is a file with perl syntax):
```
        less config_file:pl
```
 That works as well to force the call of a colorizer for a given language.

#### 5.1.1 Syntax highlighting choices
 The filter is able to do syntax highlighting for a wide variety of language
 and other format files. If installed, `bat`/`batcat` is used for coloring the
 output. If not, `pygmentize`, `source-highlight`, `code2color` is tried and finally
 `vimcolor` which is the slowest.
 Among these colorizers a preferred one can be forced for coloring by setting
 the ENV variable **LESSCOLORIZER** to the name of the colorizer.
 For `pygmentize` also a style option can be set:
```
        LESSCOLORIZER='pygmentize -O style=somename'
```
 Much better syntax highlighting is obtained using the `less` emulation of `vim`:
 The editor `vim` comes with a file `less.sh`, e.g. on Ubuntu located in
 /usr/share/vim/vimXX/macros (XX being the version number). Assuming that file
 location a function `lessc` (bash, zsh, ksh users)
```
        lessc () { /usr/share/vim/vimXX/macros/less.sh "$@"}
```
 is defined and `lessc filename` is used to view the colorful file contents.
 The same, but much slower can be achieved using the `vimcolor` colorizer.

#### 5.1.2 List of supported languages
 To see which languages are supported the list can be printed using the
following colorizer commands:

```
bat --list-languages
batcat --list-languages
pygmentize -L lexers
source-highlight --lang-list
code2color -h
vim -c "echo getcompletion('', 'filetype')" -c quit
```

### 5.2 Colored Directory listing
Depending on the operating system ls is called with appropriate options to
produce colored output.

### 5.3 Colored listing of tar file contents
If the executable archive_color is installed, then the listing of tar file
contents is colored in a similar fashion as directory contents.

## 6. Calling less from standard input

Normally `lesspipe.sh` is not called when less is used within a pipe such as
```
        cat somefile | less
```
This restriction is removed when the **LESSOPEN** variable starts with the
characters |- or||-.
Then the colon notation for extracting and displaying files in archives
does not work. As a way out `lesspipe.sh` analyses the command line and looks
for the last argument given to less. If it starts with a colon, it is
interpreted from `lesspipe.sh` as a continuation of the first parameter.
Examples:
```
        cat some_c_file | less - :c          # equivalent to less some_c_file:c
        cat archive | less - :contained_file # extracts a file from the archive
```
## 7. Displaying files with special characters in the file name

 Shell meta characters in file names: space (frequently used in windows
 file names),

 the characters | & ; ( ) ` < > " ' # ~ = $ * ? [ ] or \\

 must be escaped by a \ when used in the shell, e.g. `less a\ b.tar.gz:a\\"b`
 will display the file a"b contained in the gzipped tar archive a b.tar.gz.

## 8. Tab completion for zsh and bash

The existing `zsh` completion script has been enhanced to provide tab completion
within archives similar to what is possible with the `tar` command completion.
A `bash` completion script has been modeled loosely after the `zsh` completion.

In both shells it is now possible to complete contents of archive format files
such as tar, zip, rpm, deb files etc. This works as well in compressed files
(e.g. tar.gz) and in chained archives, e.g.in source rpm files containing
tar.gz files.

The script `lesscomplete` has to be executable and be found in one of the
directories listed in the `$PATH` environment variable. For zsh the file _less
has to be stored in one of the directories listed in `$fpath` or the directory
containig _less has to be added there, e.g. by:
```
        fpath=(~/zsh_functions $fpath)
```
In bash the function `less_completion` has to be added to the shell environment
by sourcing the script (e.g. from .bashrc using the correct location):
```
        source ~/bash_functions/less_completion
```

The completion mechanism is triggered after entering a colon or an equal sign
as for example in

```
        less archive_file:<TAB>                   # and then
        less archive_file:partial_result<TAB>
        less archive_file:contained_archive:<TAB> # etc.
```
## 9. User defined filtering

The lesspipe.sh filtering can be replaced or enhanced  by a user defined
program. Such a program has to be called `.lessfilter` and be placed in the
users home directory. It has to be executable and has to end with an exit
code 0, if the filtering was done within that script. Otherwise a nonzero
exit code means, the filtering is left to lesspipe.sh.

This mechanism can be used to add filtering for new formats or e.g. inhibit
filtering for certain file types.

## 10. (Old) documentation about lesspipe

 In English
 - https://ref.web.cern.ch/CERN/CNL/2002/001/unix-less/
 - https://www.oreilly.com/library/view/bash-cookbook/0596526784/ch08s15.html

 In German:
 - german.txt (distributed with lesspipe, not updated)
 - https://www.linux-magazin.de/ausgaben/2001/01/bessere-sicht/
 - https://www.linux-community.de/ausgaben/linuxuser/2002/04/lesspipe/

## 11. External links

(last checked: Nov 30 2021):

### 11.1 URLs to some utilities (with last known release)
- 7zr                  https://sourceforge.net/projects/p7zip/ (2016)
- antiword             https://www.winfield.demon.nl/ (2005)
- cabextract           https://www.cabextract.org.uk/ (2019)
- catdoc,catppt,xls2csv https://www.wagner.pp.ru/~vitus/software/catdoc/ (2016)
- ccze                 https://github.com/cornet/ccze (2011)
- djvutxt              https://sourceforge.net/projects/djvu/ (2021)
- docx2txt             https://docx2txt.sourceforge.net/ (2014)
- dvi2tty              https://www.ctan.org/tex-archive/dviware/dvi2tty/ (2016)
- excel2csv            https://github.com/informationsea/excel2csv (2018)
- html2text            https://www.mbayer.de/html2text/ (2016 version 1.3.2a)
- id3v2                https://id3v2.sourceforge.net/ (2010)
- lzip                 https://download.savannah.gnu.org/releases/lzip/ (2021)
- matdump              https://github.com/tbeu/matio (2021)
- mediainfo            https://mediaarea.net/MediaInfo/ (2021)
- odt2txt              https://github.com/dstosberg/odt2txt (2017)
- pandoc               https://pandoc.org/ (2021)
- pptx2md              https://github.com/ssine/pptx2md (2021)
- tarcolor             https://github.com/msabramo/tarcolor (modified, 2021)
- unrtf                https://ftp.gnu.org/gnu/unrtf/ (2018)
- wvText               https://github.com/AbiWord/wv/ (2014)
- xlscat               https://metacpan.org/pod/Spreadsheet::Read (2021)
- sxw2txt              https://vinc17.net/software/sxw2txt (2015)

### 11.2 References
- [1] http://www.greenwoodsoftware.com/less/	(less)
- [2] ftp://ftp.astron.com/pub/file/		(file)
- [3] https://github.com/wofr06/lesspipe
- [5] http://www.palfrader.org/code2html/	(code2html)
- [6] http://www.darwinsys.com/file/		(file)

## 12. Contributors

 The script lesspipe.sh is constantly enhanced thanks to suggestions from
 users. Thanks to (in alphabetical order):
 (contributors after Sep 2015 see github history)

 Marc Abramowitz, James Ahlborn, Sören Andersen, Andrew Barnert,
 Peter D. Barnes, Jr., Eduard Bloch, Mathieu Bouillaguet, Florian Cramer,
 Philippe Defert, Antonio Diaz Diaz, Bastian Fuchs, Matt Ghali, Carl Greco,
 Stephan Hegel, Michel Hermier, Tobias Hoffmann, Christian Höltje,
 Jürgen Kahnert, Sebastian Kayser, Ben Kibbey, Peter Kostka,
 Heinrich Kuettler, Antony Lee, Vincent Lefèvre, David Leverton, Jay Levitt,
 Vladimir Linek, Oliver Mangold, Istvan Marko, Markus Meyer, Remi Mommsen,
 Derek B. Noonburg, Martin Otte, Jim Pryor, Slaven Rezic, Daniel Risacher,
 Jens Schleusener, Ken Teague, Matt Thompson, Paul Townsend, Petr Uzel,
 Chelban Vasile, Götz Waschk, Michael Wiedmann, Dale Wijnand, Peter Wu.
