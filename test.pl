#!/usr/bin/env perl
#use strict;
#use warnings;

sub usage {
	print <<EOF;
Usage: $0 [-d] [-n] [testnumber[s]] [file_name]
  Test lesspipe.sh against a number of files and report failures
  -n        The test commands are printed only, not checked
  -d        Print the output of failing commands and the test string
  file_name The script to test against in the current directory [lesspipe.sh]
  The test commands and test strings are stored at the end of this program
  The '= some string' means, that 'some string' including a newline char
  must be the test result. The '~ match string' means, that 'match string'
  must match a complete line in the output, the 'c string' must match string
  surrounded with Escape sequences..
EOF
	exit;
}

use vars qw(%ENV);

my ($debug, $noaction, $fname, @numtest);
$fname = 'lesspipe.sh';
while ($ARGV[0]) {
	if ($ARGV[0] =~ /^\-([dn]$)/) {
		$debug = 1 if $1 =~ /d/;
		$noaction = 1 if $1 =~ /n/;
		shift;
	} elsif ($ARGV[0] =~ /^\d+/) {
		push @numtest, shift;
	} else {
		usage() if ! -r $ARGV[0];
		$fname = shift;
	}
}
$fname = "./$fname" if $fname !~ m|/|;
$ENV{LESSOPEN} = "|$fname %s";
# to check all test cases with the filter
$ENV{LESS_ADVANCED_PREPROCESSOR} =1;
$ENV{LESSQUIET} =1;
my $duration = time();
my ($retcode, $sumok, $sumignore, $sumnok, $num) = (0, 0, 0, 0, 0);
while (<DATA>) {
  my $cmd = $_;
  next if /^#|^\s*$/;
  chomp $cmd;
  my $comp = <DATA>;
  $num++;
  next if @numtest and ! grep {$num == $_} @numtest;
  my $comment = $1 if $cmd =~ s/\s+#(.*)//;
  if ($noaction) {
	print "$cmd\n";
	next;
  }
  my $res = `$cmd 2>&1`;
  my $ok = 0;
  my $ignore = 0;
  my $lines = 0;
  # zsh|bash|ksh style|file not found
  if ($res =~ /command not found: (\S+)|(\S+):\s+command not found|(\S+):\s+not found|no such file or directory: .*?([^\/]+)\b$/m) {
    $res = "NOT found: " . $1|$2|$3|$4;
    $ok = 1;
  } else {
	$ok = comp($res, $comp);
	my $needed = $1 if $comment =~ s/[#,]? needs (.*)//;
	$needed =~ s/ or /|/g;
	$needed =~ s/ and /,/g;
	my @needed = split /\s*\|\s*/, $needed;
	$ignore = 1 if @needed;
	for my $andargs (@needed) {
		my $good = 1;
		for (split /\s*,\s*/, $andargs) {
			$good = 0 if is_not_exec($_);
		}
		$ignore = 0 if $good;
	}
	if ($ignore) {
		$sumignore++;
	} elsif ($ok) {
		$sumok++;
	} else {
		$sumnok++;
	}
  }
  print "result:$res" if $ok and $debug;
  printf "%2d %6s %s\n", $num, $ignore ? 'ignore' : $ok ? $ok: 'NOT ok', $comment;
  print "\t   failing command: $cmd\n" if ! $ok;
}

$duration = time() - $duration;
print "$sumok/$sumignore/$sumnok tests passed/ignored/failed in $duration seconds\n" if ! $noaction;
exit $sumnok;

sub is_not_exec {
  my $arg = shift;
  return 0 if ! $arg;
  for my $prog (split ' ', $arg) {
    return 1 if ! grep {-x "$_/$prog"} split /:/, $ENV{PATH};
  }
  return undef;
}

sub comp {
	my ($res, $comp) = @_;
	chomp $comp;
	my $ok = '';
	if ($comp =~ s/^= //) {
		# ignore leading and trailing newlines
		$res =~ s/^\n//g;
		$res =~ s/\0//g;
		$res =~ s/\n$//g;
		return 'ok' if $comp eq $res;
		print ":$res:\ndiffers from\n:$comp:\n" if $debug;
	} elsif ($comp =~ s/^~ //) {
		return 'ok' if $res =~ /^$comp$/m;
		print ":$res:\ndoes not match\n:$comp:\n" if $debug;
	} elsif ($comp =~ s/^c //) {
		$ok = join '', grep {s/.*\s(\S+)$comp(\S+).*/$1ok$2/} split /\n/, $res;
	}
	return $ok;
}
__END__
less testok/a\ b							# view a file with spaces in the name
= test
less testok/symlink						# symbolic link to a\ b
= test
less testok/a\ b.tgz:testok/a\ text.gz	# view the file testok/a\ b.gz contained in the gzipped tar archive, needs gzip
= test
less testok/a\ b.tgz:testok/a\<b.zip:testok/a\<b # view testok/a\<b in testok/a\<b.zip which is also in the tar archive, needs unzip
= test
less testok/a\ b.tgz:testok/a\>b.bz2		# bzip2 compressed data, needs bzip2
= test
less -r testok/a\ b.tgz:testok/a\ text.gz:.ruby # bzip2 compressed data, try to switch on syntax highlighting (.ruby), needs gzip
c test
less -r testok/a\ b.tgz:testok/a::b::c::d.gz:ruby # view the gzipped file testok/a::b::c::d.gz assuming it is a ruby file, needs gzip
c test
less testok/a\ b.tgz:testok/a\`data.gz	# check special chars # needs gzip
= test
less testok/a\ b.tgz:testok/a=ar.gz:a=b  # current ar archive # needs gzip
= test
less testok/a\ b.tgz:testok/a\'html.gz	# HTML document # needs gzip,xhtml2text
= test
less testok/a\ b.tgz:testok/a\"doc.gz    # Composite Document File V2 (2005) # needs gzip
= test
less testok/a\#rtf						# Rich Text Format, needs unrtf
~ TITLE: test$|^test
less testok/a\ b.tgz:testok/a\&pdf.gz	# PDF document 1.3, needs gzip
~ test
less testok/a\ b.tgz:testok/a\;dvi.gz	# TeX DVI file, needs gzip,dvi2tty
~ test
less testok/a\ b.tgz:testok/a\(ps.gz		# PostScript 2.0, needs gzip
~ \s+test\s*
less testok/a\ b.tgz:testok/a\)nroff.gz	# troff or preprocessor, needs troff
~ test \(1\).*
less -f testok/perlstorable.gz				# perl Storable (0.7), needs gzip
~ test
less testok/iso.image					# ISO 9660 CD-ROM listing, needs isoinfo
~ /ISO.TXT;1$|^.*---.*\sISO.TXT;1\s*
less testok/iso.image:/ISO.TXT\;1		# ISO 9660 CD-ROM file content, needs isoinfo
= test
less testok/test.rpm:test.txt			# RPM v3, needs rpm2cpio
= test
less testok/cabinet.cab:a\ text.gz       # Cabinet archive data, needs cabextract
= test
less testok/test.deb:./test.txt			# Debian binary package, needs ar,gzip
= test
less testok/test2.deb:./test.txt			# Debian, converted from rpm, needs ar,gzip
= test
less testok/a\ b.tgz:testok/a\~b.odt		# OpenDocument Text
= test
less testok/a\|b.7za:testok/a\|b.txt		# 7-zip archivedata, needs 7za or 7zr
= test
less -f testok/onefile.7za					# 7-zip single file, needs 7za or 7zr
= test
less testok/a\ b.tgz:testok/onefile.7za	# 7-zip single file, needs 7za or 7zr
= test
less testok/a\ b.tgz:testok/a\|b.7za:testok/a\|b.txt # recursive packing, needs 7za or 7zr
= test
less testok/test.rar:testok/a\ b			# RAR archive data v4 needs unrar|rar|bsdtar
= test
less testok/a\ b.br								# brotli compressed file needs brotli
= test
less -f testok/test.utf16					# UTF-16 Unicode needs iconv
= test
less -f testok/test.mp3						# Audio with ID3 2.4 MPEG layer III needs mediainfo|exiftool
~ Title\s+:\stest\s*.*
less -f testok/id3v2.mp3                    # Audio with ID3 2.3 MPEG layer III needs mediainfo|exiftool
~ Title\s+:\stest$|^TIT2.*:\stest
less -f testok/a\?b.gz						# check special chars
= test
less -f testok/a\[b.gz						# check special chars
= test
less -f testok/a\]b.gz						# check special chars
= test
less testok/a\ test						# directory
~ -rw-.*test
less testok/a:test						# directory with colon
~ -rw-.*test
less testok/test.zst						# Zstandard compressed data 0.8, needs zstd
= test
less testok/test.tzst				# tar file using zstd compression, needs zstd
~ .* testok/test
less testok/test.zst.tzst:test.zst		# Zstandard compressed data 0.8, needs zstd
= test
less testok/test.tar.zst					# tar file of a zstd compressed file, needs zstd
~ .* testok/test
less testok/test:a.tbz=testok/a::b::c::d	# Alternate separator char
~ test$|^.*test.*
less testok/test.class.gz					# Java class file, needs procyon
~ public class test
