#!/usr/bin/env perl
my @pkgs;
if (@ARGV) {
    @pkgs = @ARGV;
}
else {
    die "Usage: sign-and-queue-packages *.changes vendor/*.changes\n\nSigns all changes files and then queues that file and the other 3 in codesigner's incoming directory\n";
}

unless ($ENV{MYGPGKEY}) {
    die "The environment variable MYGPGKEY is not set!  Set it in your .bashrc.";
}

if (@pkgs == 0) {
    die "no files in the pwd ending in .changes, and no .changes files specified on the cmdline!";
}

for my $changes_file (@pkgs) {
    unless (-e $changes_file) {
        warn "file: $changes_file not found!  skipping...\n";
        next;
    }

    my $prefix = $changes_file;
    $prefix =~ s/_[^_]+.changes//;
    print "c: $changes_file\n";
    print "p: $prefix\n";

    my @all_files = glob("$prefix*");
    my $cnt = scalar(@all_files);
    print "cnt: $cnt\n";
    unless ($cnt == 4) {
        warn "did not find exactly 4 files in the directory with prefix $prefix!  skipping...\n";
        next;
    }

    my @cmds = (
        "debsign -k$ENV{MYGPGKEY} $changes_file" => '** signing files...',
        "chmod 664 $prefix*" => "** setting permissions...",
        "chgrp info $prefix*" => "** setting the group to info...",
        "mv $prefix* ~codesigner/incoming/lucid-genome-development/" => "** moving files to codesigner queue",
    );

    while (@cmds) {
        my $cmd = shift @cmds;
        my $msg = shift @cmds;
        print "$msg\n  RUNNING: $cmd\n";
        my $rv = system $cmd; 
        $rv/=256;
        if ($rv) {
            warn "  ERROR: $msg (skipping $prefix): $!";
            next;
        }
    }
}

