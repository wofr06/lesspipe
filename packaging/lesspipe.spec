%global debug_package %{nil}

%global lesspipe_exec_dir	%{_libexecdir}/%{name}
%global bash_completion		%{_datarootdir}/bash-completion/completions
%global zsh_completion		%{_datarootdir}/zsh/site-functions

%define packagename lesspipe
%define packageversion 2.28
%define packagerelease 1

Name:		%{packagename}
Version:	%{packageversion}
Release:	%{packagerelease}%{?dist}
Summary:	Input filter for less to better display files
License:	GPL-2.0-or-later
URL:		https://lesspipe.org/
Packager:	Wolfgang Friebel <wp.friebel@gmail.com>
Source0:	https://github.com/wofr06/lesspipe/archive/refs/tags/v%{version}.tar.gz
Source1:	profile-lesspipe.sh
Source2:	profile-lesspipe.csh
BuildArch:	noarch
AutoReqProv:	on

Requires:	less
Requires:	/usr/bin/ps
# suggested by the author Wolfgang Friebel
Recommends:	bat
Suggests:	(elinks or lynx or w3m)
Suggests:	(vim-enhanced or neovim)

BuildRequires:	bash
BuildRequires:	diffutils
BuildRequires:	glibc-langpack-en
BuildRequires:	less
BuildRequires:	make
# try to run as many tests as possible from test.sh
#BuildRequires:	/usr/bin/7za
#BuildRequires:	/usr/bin/brotli
#BuildRequires:	/usr/bin/bsdtar
#BuildRequires:	/usr/bin/cabextract
#BuildRequires:	/usr/bin/djvutxt
#BuildRequires:	/usr/bin/elinks
#BuildRequires:	/usr/bin/exiftool
#BuildRequires:	/usr/bin/ffprobe
#BuildRequires:	/usr/bin/groff
#BuildRequires:	/usr/bin/isoinfo
#BuildRequires:	/usr/bin/h5dump
#BuildRequires:	/usr/bin/lz4
#BuildRequires:	/usr/bin/lzip
#BuildRequires:	/usr/bin/lzma
#BuildRequires:	/usr/bin/openssl
#BuildRequires:	/usr/bin/pandoc
#BuildRequires:	/usr/bin/pigz
#BuildRequires:	/usr/bin/plistutil
BuildRequires:	/usr/bin/ps
#BuildRequires:	/usr/bin/ps2ascii
BuildRequires:	/usr/bin/unzip
BuildRequires:	/usr/bin/vim
BuildRequires:	/usr/bin/xz
#BuildRequires:	/usr/bin/sqlite3
# needed for color tests in test.sh
BuildRequires:	bat
#BuildRequires:	/usr/bin/dtc
#BuildRequires:	/usr/bin/pandoc
#BuildRequires:	/usr/bin/pygmentize
#BuildRequires:	/usr/bin/source-highlight
#%if 0%{?fedora}
#BuildRequires:	/usr/bin/dvi2tty
#BuildRequires:	/usr/bin/matdump
#BuildRequires:	/usr/bin/odt2txt
#BuildRequires:	libreoffice
#%endif

%description
lesspipe.sh is an input filter for the pager less. It is able to process a
wide variety of file formats. It enables users to deeply inspect archives
and to display the contents of files in archives without having to unpack
them before. That means file contents can be properly interpreted even if
the files are compressed and contained in a hierarchy of archives (often
found in RPM or DEB archives containing source tarballs). The filter is
easily extensible for new formats. The input filter is a bash script, but
works as well as a zsh script. For zsh and bash tab completion mechanisms
for archive contents are provided.

%package profile
Summary:   Input filter for less to better display files - profile scripts

%description profile
lesspipe.sh is an input filter for the pager less. It is able to process a
wide variety of file formats. It enables users to deeply inspect archives
and to display the contents of files in archives without having to unpack
them before. That means file contents can be properly interpreted even if
the files are compressed and contained in a hierarchy of archives (often
found in RPM or DEB archives containing source tarballs). The filter is
easily extensible for new formats. The input filter is a bash script, but
works as well as a zsh script. For zsh and bash tab completion mechanisms
for archive contents are provided.

This package contains profile scripts to automatically set LESSOPEN
on login.

%prep
%autosetup

%build
./configure --prefix=%{_prefix} --bindir=%{lesspipe_exec_dir} --libexecdir=%{lesspipe_exec_dir} --bash-completion-dir=%{bash_completion} --zsh-completion-dir=%{zsh_completion}

%install
%make_install

# create profile.d scripts to set LESSOPEN
mkdir -p %{buildroot}%{_sysconfdir}/profile.d
sed -e "s@__BINDIR__@%{lesspipe_exec_dir}@g" %{SOURCE1} > %{buildroot}%{_sysconfdir}/profile.d/50-lesspipe.sh
sed -e "s@__BINDIR__@%{lesspipe_exec_dir}@g" %{SOURCE2} > %{buildroot}%{_sysconfdir}/profile.d/50-lesspipe.csh

%check

env TERM=xterm-256color ./test.sh %{buildroot}%{lesspipe_exec_dir}/lesspipe.sh

%files
%dir %{lesspipe_exec_dir}
%{lesspipe_exec_dir}/*
%dir %{bash_completion}
%{bash_completion}/*
%dir %{zsh_completion}
%{zsh_completion}/*
%{_mandir}/man1/lesspipe.1.*
%license LICENSE
%doc ChangeLog INSTALL README.md german.txt

%files profile
%{_sysconfdir}/profile.d/*

%changelog
* Tue Sep 08 2026 2.28-1 - wp.friebel@gmail.com
- improvements for watching growing files and text files with large HTML content
* Wed Jun 10 2026 2.27-1 - wp.friebel@gmail.com
- better certicicate files handling, add sqlite db display
* Fri Jun 05 2026 2.26-1 - wp.friebel@gmail.com
- speed up log file processing and improve color handling
* Sat Apr 25 2026 2.25-1 - wp.friebel@gmail.com
- emacs based colorizer e2ansi-cat added, procyon output can get colored
* Sat Apr 04 2026 2.24-1 - wp.friebel@gmail.com
- no more perl dependency, log files can get colorized using tspin
* Sat Mar 21 2026 2.23-1 - wp.friebel@gmail.com
- more consistent test suite, convert some scripts from perl to bash
* Mon Dec 15 2025 2.22-1 - wp.friebel@gmail.com
- bug fixes, documentation changes, sxw2txt and code2color removed
* Mon Nov 24 2025 2.21-1 - wp.friebel@gmail.com
- documentation changes, markdown support changed, correctly report empty files
* Fri Sep 12 2025 2.20-1 - wp.friebel@gmail.com
- make lesspipe compatible with termux
* Thu Jul 17 2025 2.19-1 - wp.friebel@gmail.com
- installation and documentation enhancements, use ffprobe for videos
* Sun Feb 16 2025 2.18-1 - wp.friebel@gmail.com
- documentation enhanced, better xlsx support
* Sun Dec 22 2024 2.17-1 - wp.friebel@gmail.com
- Fixes for xslx and MacOS
* Sun Nov 10 2024 2.16-1 - wp.friebel@gmail.com
- file name checks for ar
* Thu Oct 03 2024 2.15-1 - wp.friebel@gmail.com
- display all certificates in pem files
* Fri Aug 16 2024 2.14-1 - wp.friebel@gmail.com
- prefer nvimpager for coloring if installed
* Fri May 10 2024 2.13-1 - wp.friebel@gmail.com
- support appimage and snap files 
* Mon Mar 18 2024 2.12-1 - wp.friebel@gmail.com
- improved completion mechanism
* Wed Dec 13 2023 2.11-1 - wp.friebel@gmail.com
- changed output for csv files
* Thu Oct 05 2023 2.10-1 - wp.friebel@gmail.com
- added zlib support, recognize jsx and tsx, view csv files using column
* Mon Jun 26 2023 2.08-1 - wp.friebel@gmail.com
- improved coloring output, support for device tree blob files, bug fixes
* Sun Jan 08 2023 2.07-1 - wp.friebel@gmail.com
- support json, mail archives, update man page, other bat/batcat defaults
* Wed Aug 17 2022 2.06-1 20220817 - wp.friebel@gmail.com
- remove perl storable files handling, changes recommended by Shellcheck
* Tue Apr 26 2022 2.05-1 20220426 - wp.friebel@gmail.com
- fix colorizing using bat and for file names containing spaces
* Mon Feb 28 2022 2.04-1 20220228 - wp.friebel@gmail.com
- handle csv files, lessfilter can be in path
* Tue Feb 22 2022 2.03-1 20220222 - wp.friebel@gmail.com
- better handling of colorizing, improved code2color
* Wed Jan 19 2022 2.02-1 20220119 - wp.friebel@gmail.com
- add .lessfilter support, fixes for html and rpm handling
* Tue Jan 04 2022 2.01-1 20220104 - wp.friebel@gmail.com
- added zsh completion mechanism for archive contents
* Tue Dec 28 2021 2.00-1 20211228 - wp.friebel@gmail.com
- heavily rewritten version
* Tue Jul 28 2015 1.83-1 20150728 - Wolfgang.Friebel@desy.de
- new version (see ChangeLog)
* Mon Feb 04 2013 1.82-1 20130204 - Wolfgang.Friebel@desy.de
- protect against iconv errors
* Mon Jan 14 2013 1.81-1 20130114 - Wolfgang.Friebel@desy.de
- initial build starting with (prerelease of) lesspipe version 1.81
