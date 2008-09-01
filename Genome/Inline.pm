
package Genome::Inline;
use strict;
use warnings;

our $DIRECTORY;
sub DIRECTORY {
    unless(defined $DIRECTORY) {
        $DIRECTORY = $INC{"Genome/Inline.pm"};
        $DIRECTORY =~ s/\.pm(\/|)//;
        $DIRECTORY .= 32;
        unless (-d $DIRECTORY) {
            unless(mkdir $DIRECTORY) {
                die "failed to create directory $DIRECTORY: $!";
            }
        }
    }
    return $DIRECTORY;
}

our $CCFLAGS;
sub CCFLAGS {
    unless (defined($CCFLAGS)) {
        $CCFLAGS = `uname -m` =~ /ia64/?'-D_FILE_OFFSET_BITS=64 -m32':'-D_FILE_OFFSET_BITS=64';
    }
    return $CCFLAGS;
}

1;

