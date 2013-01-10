#!/usr/bin/env perl
#use strict;
#use warnings;

use vars qw(%ENV);

my $debug = 0;
$debug = 1 if $ARGV[0] and $ARGV[0] eq '-d';

$ENV{LESSOPEN} = "|./lesspipe.sh %s";
$ENV{PATH} .= ":."; # make sure we do find sxw2txt
open F, "TESTCMDS" or die "Could not read TESTCMDS:$!\n";
my $retcode = 0;
my $duration = time();
my $sumok = 0;
my $sumignore = 0;
my $sumnok = 0;
while (<F>) {
  next if /^#/;
  next if /^\s*$/;
  chomp;
  my $ignore = $_ =~ s/#\s*ignore error*//;
  my $res = `$_ 2>&1`;
  my $ok = 0;
  my $lines = 0;
  if ( $res and $res =~ /command not found: (\S+)/m ) {  # zsh style
    print "result:$res" if $debug;
    $res = "NOT found: $1";
    $ok = 1;
  } elsif ( $res and $res =~ /(\S+):\s+command not found/m ) { # bash style
    print "result:$res" if $debug;
    $res = "NOT found: $1";
    $ok = 1;
  } elsif ( $res and $res =~ /(\S+):\s+not found/m ) { # ksh style
    print "result:$res" if $debug;
    $res = "NOT found: $1";
    $ok = 1;
  } elsif ( $res and $res =~ /no such file or directory: .*?([^\/]+)\b$/m ) {
    print "result:$res" if $debug;
    $res = "NOT found: $1";
    $ok = 1;
  } elsif ( $res ) {
    print "result:$res" if $debug;
    my @res = split /\n/, $res;
    shift @res if $res[0] =~ /^==>/;
    shift @res while @res and $res[0] =~ /^\s*$/;
    # special case for directory listing
    $res[0] = 'test' if $res =~ /total \d+\b.*r--r--.*test/s;
    $ok = $res[0] =~ /^\s*(\e\[36m)?test(\e\[0m)?\s*$/ if $res[0];
    # special case for nroff
    $ok = $res[0] =~ s/^test \(1\)\s+.*/test/ if $res[0] and ! $ok;
    # special case for perl storable
    $ok = $res[0] =~ s/^\$VAR1 = \\'test';$/test/ if $res[0] and ! $ok;
    # special case for mp3
    if ($res[1] and ! $ok) {
        $ok = $res[1] =~ s/.*Title.*:\s+test\b.*/test/;
        $res[0] = $res[1] if $ok;
    }
    $res = $res[0] if $res[0];
    $lines = $#res;
  }
  if ( $ok ) {
    $res =~ s/test/ok/ if $ok;
    $res =~ s/^\s+// if $ok;
    #$res .= " ($lines trailing lines)" if $lines;
    $sumok++;
  } else {
    $retcode++ if ! $ok and ! $ignore;
    $res = "NOT ok";
    $res .= " (ignored)" if $ignore;
    $sumnok++ if ! $ignore;
    $sumignore++ if $ignore;
  }
  printf "%-56s %s\n", $_, $res;
}
close F;
$duration = time() - $duration;
print "$sumok/$sumignore/$sumnok tests passed/ignored/failed in $duration seconds\n";
exit $retcode;
