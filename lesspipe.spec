%define packagename lesspipe
%define packageversion 1.82
%define packagerelease 1

Name:          %{packagename}
Version:       %{packageversion}
Release:       %{packagerelease}
Group:         Languages
Source0:       lesspipe-%{packageversion}.tar.gz
BuildArch:     noarch
AutoReqProv:   on
Packager:      Wolfgang Friebel <wolfgang.friebel@desy.de>
URL:           https://sourceforge.net/projects/lesspipe/files/latest/download
License:       GPL
BuildRoot:     /var/tmp/%{packagename}-%{packageversion}
Summary:       Input filter for less to better display files

%description
lesspipe.sh is an input filter for the pager less. The script runs under a
ksh-compatible shell (e.g. bash, zsh) and allows you to use less to view
files with binary content, compressed files, archives, and files contained
in archives. It supports many formats (both as plain and compressed files
using gzip, bzip2 and other pack programs). For details please consult the
README file contained in the package. Syntax highlighting of source code is
possible through an included script 'code2color'.

%prep
%setup -n lesspipe-%{packageversion}

%build

%define prefix /usr/local
./configure --fixed --prefix=$RPM_BUILD_ROOT%{prefix}

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
%{prefix}/bin/code2color
%{prefix}/bin/sxw2txt
%{prefix}/bin/tarcolor
%{prefix}/share/man/man1
/etc/profile.d

%docdir %{prefix}/share/man/man1

%changelog
* Mon Feb 04 2013 1.82-1 20130204 - Wolfgang.Friebel@desy.de
- protect against iconv errors
* Mon Jan 14 2013 1.81-1 20130114 - Wolfgang.Friebel@desy.de
- initial build starting with (prerelease of) lesspipe version 1.81
