%define packagename lesspipe
%define packageversion 2.11
%define packagerelease 1

Name:          %{packagename}
Version:       %{packageversion}
Release:       %{packagerelease}
Group:         Languages
Source0:       lesspipe-%{packageversion}.tar.gz
BuildArch:     noarch
AutoReqProv:   on
Packager:      Wolfgang Friebel <wp.friebel@gmail.com>
URL:           https://github.com/wofr06/lesspipe.sh/archive/lesspipe.zip
License:       GPL
BuildRoot:     /var/tmp/%{packagename}-%{packageversion}
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

%define prefix /usr/local
./configure --prefix=$RPM_BUILD_ROOT%{prefix}

%install
#
# after some safety checks, clean out the build root
#
[ ! -z "$RPM_BUILD_ROOT" ] &&  [ "$RPM_BUILD_ROOT" !=  "/" ] && \
    rm -rf $RPM_BUILD_ROOT

#run install script first so we can pick up all of the files

make install

# create profile.d scripts to set LESSOPEN
mkdir -p $RPM_BUILD_ROOT/etc/profile.d
cat << EOF > $RPM_BUILD_ROOT/etc/profile.d/zzless.sh
[ -x %{prefix}/bin/lesspipe.sh ] && export LESSOPEN="|%{prefix}/bin/lesspipe.sh %s"
EOF
cat << EOF > $RPM_BUILD_ROOT/etc/profile.d/zzless.csh
if ( -x %{prefix}/bin/lesspipe.sh ) then
  setenv LESSOPEN "|%{prefix}/bin/lesspipe.sh %s"
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
%{prefix}/bin/lesspipe.sh
%{prefix}/bin/archive_color
%{prefix}/bin/code2color
%{prefix}/bin/vimcolor
%{prefix}/bin/sxw2txt
%{prefix}/bin/lesscomplete
%{prefix}/share/man/man1/*
%{prefix}/share/zsh/site-functions
%{prefix}/share/bash-completion
/etc/profile.d/*

%docdir %{prefix}/share/man/man1

%changelog
* Wed Dec 13 2023 2.11-1 - wp.friebel@gmail.com
- changed output for csv files
* Tue Oct 05 2023 2.10-1 - wp.friebel@gmail.com
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
