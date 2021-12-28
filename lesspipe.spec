%define packagename lesspipe
%define packageversion 2.00
%define packagerelease 1

Name:          %{packagename}
Version:       %{packageversion}
Release:       %{packagerelease}
Group:         Languages
Source0:       lesspipe-%{packageversion}.tar.gz
BuildArch:     noarch
AutoReqProv:   on
Packager:      Wolfgang Friebel <wolfgang.friebel@desy.de>
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
works as well as a zsh script.

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
%{prefix}/bin/archive_color
%{prefix}/bin/code2color
%{prefix}/bin/vimcolor
%{prefix}/bin/sxw2txt
%{prefix}/share/man/man1
/etc/profile.d

%docdir %{prefix}/share/man/man1

%changelog
* Tue Dec 28 2021 2.00-1 20211228 - wp.friebel@gmail.com
- heavily rewritten version
* Tue Jul 28 2015 1.83-1 20150728 - Wolfgang.Friebel@desy.de
- new version (see ChangeLog)
* Mon Feb 04 2013 1.82-1 20130204 - Wolfgang.Friebel@desy.de
- protect against iconv errors
* Mon Jan 14 2013 1.81-1 20130114 - Wolfgang.Friebel@desy.de
- initial build starting with (prerelease of) lesspipe version 1.81
