%define packagename lesspipe
%define packageversion 2.20
%define packagerelease 1

Name:          %{packagename}
Version:       %{packageversion}
Release:       %{packagerelease}%{?dist}
Group:         Languages
Source0:       https://github.com/ahaupt/lesspipe/archive/refs/tags/v%{packageversion}.tar.gz
BuildArch:     noarch
AutoReqProv:   on
Packager:      Wolfgang Friebel <wp.friebel@gmail.com>
URL:           https://github.com/wofr06/lesspipe/
License:       GPL
BuildRoot:     /var/tmp/%{packagename}-%{packageversion}
BuildRequires: make perl bash zsh
Summary:       Input filter for less to better display files

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

%prep
%setup -n lesspipe-%{packageversion}

%build

%define prefix /usr
%define bindir %{prefix}/libexec/%{name}
%define bash_completion %{_datarootdir}/bash-completion/completions
%define zsh_completion %{_datarootdir}/zsh/site-functions
./configure --prefix=%{prefix} --bindir=%{bindir} --bash-completion-dir=%{bash_completion} --zsh-completion-dir=%{zsh_completion}

%install
#
# after some safety checks, clean out the build root
#
[ ! -z "$RPM_BUILD_ROOT" ] &&  [ "$RPM_BUILD_ROOT" !=  "/" ] && \
    rm -rf $RPM_BUILD_ROOT

#run install script first so we can pick up all of the files

make install DESTDIR=$RPM_BUILD_ROOT

# create profile.d scripts to set LESSOPEN
mkdir -p $RPM_BUILD_ROOT/etc/profile.d
cat << EOF > $RPM_BUILD_ROOT/etc/profile.d/zzless.sh
[ -x %{bindir}/lesspipe.sh ] && export LESSOPEN="|%{bindir}/lesspipe.sh %s"
EOF
cat << EOF > $RPM_BUILD_ROOT/etc/profile.d/zzless.csh
if ( -x %{bindir}/lesspipe.sh ) then
  setenv LESSOPEN "|%{bindir}/lesspipe.sh %s"
endif
EOF

%clean

cd $RPM_BUILD_DIR
[ ! -z "$RPM_BUILD_ROOT" ] &&  [ "$RPM_BUILD_ROOT" !=  "/" ] && \
    rm -rf $RPM_BUILD_ROOT
[ ! -z "$RPM_BUILD_DIR" ] &&  [ "$RPM_BUILD_DIR" !=  "/" ] && \
    rm -rf $RPM_BUILD_DIR/lesspipe-%{packageversion}

%pre

%post

%preun

%postun

%files

%defattr(-,root,root)
%doc ChangeLog COPYING INSTALL README.md german.txt
%dir %{bindir}
%{bindir}/lesspipe.sh
%{bindir}/archive_color
%{bindir}/code2color
%{bindir}/vimcolor
%{bindir}/sxw2txt
%{bindir}/lesscomplete
%{_mandir}/man*/*
%{bash_completion}
%{zsh_completion}
/etc/profile.d/*

#%docdir %{prefix}/share/man/man1

%changelog
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
