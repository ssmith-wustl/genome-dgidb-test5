!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use IO::File;

my $dir = 'debian';

my $path = $FindBin::Bin . "/$dir-list";
my $fh = IO::File->new($path);
$fh or die "failed to open file $path: $!";
my @list = $fh->getlines;

my $new_content = <<EOS 
Source: genome-snapshot-deps-perl
Section: science
Priority: optional
Maintainer: The Genome Institute <gmt\@genome.wustl.edu>
Build-Depends: debhelper (>= 7)
Build-Depends-Indep: perl
Standards-Version: 3.8.3

Package: genome-snapshot-deps-perl
Architecture: all
Provides: genome
Depends: ${misc:Depends}, ${perl:Depends}, 
EOS
@list
Description: This meta-package installs all dependencies of the current internal TGI software snapshot
EOS

my $prev_control_path = $FindBin::Bin . "/$dir/control";
my $prev_fh = IO::File->new($previous_control_path);
$prev_fh or die "failed to open temp file $prev_control_path: $!";
my $prev_content = join('',$prev_fh->getlines);

if ($prev_content eq $new_content) {
    print "Content matches for " . scalar(@lines) . " packages.  No updates.\n";
    exit;
}
else {
    print "Updated packages...\n";

    my $new_control_path = $prev_control_path . '.new';
    my $new_fh = IO::File->new('>' . $new_control_path);
    $new_fh or die "failed to open temp file $new_control_path: $!";
    $new_fh->print($new_content);
    $new_fh->close;

    my $rv = system "diff $prev_control_path $new_control_path";
    $rv /= 256;
    if ($rv) {
        die "error diffing $prev_control_path and $new_control_path: $!"
    }

    my $rv = system "cat $new_control_path > $prev_control_path";
    $rv /= 256;
    if ($rv) {
        die "error rewriting $prev_control_path from $new_control_path: $!"
    }

    print "Update complete for $prev_control_path.\n";
}

