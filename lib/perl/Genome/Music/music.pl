#!/gsc/bin/perl

use warnings;
use strict;

use lib "Music/lib/";
use Music;
use Getopt::Long;

=head1 VERSION

    Version 1.01

=head1 SYNOPSIS

    MUSIC - MUtation SIgnificance In Cancer - the cancer genome analysis package from the Genome Center at Washington University

=head1 USAGE    music.pl [command]

=head3 COMMAND OPTIONS

=cut

our $VERSION = '1.01';

my $analysis = Music::new();

=head1 AUTHOR

    Nathan Dees, << <ndees at genome.wustl.edu> >>
    The Genome Center at Washington University School of Medicine
    St. Louis, Missouri, USA

=head1 COPYRIGHT

    Copyright 2010 The Genome Center at Washington University School of Medicine
    All rights reserved.

=head1 LICENSE

    This program is free for non-commercial use.

=cut
