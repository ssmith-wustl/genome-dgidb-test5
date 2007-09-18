#! /gsc/bin/perl

use strict;
use warnings;

use lib '/gscuser/ebelter/dev/svn/perl_modules/';

use Test::Class;

Test::Class->runtests('Crossmatch::Test');

exit 0;

#######################################################

package Crossmatch::Test;

use strict;
use warnings;

use base 'Test::Class';

use Data::Dumper;
use Crossmatch::Reader;
use IO::File;
use IO::String;
use Test::More;

sub test01_read_alignments : Tests
{
    my $self = shift;

    my $class = 'Crossmatch::Reader';
    print "Testing $class\n";
    
    my $fh = IO::File->new('< cm.out')
        or die"$!\n";

    my $reader = $class->new
    (
        io => $fh,
        return_as_objs => 1,
    )
        or die;
    ok($reader, "Created $class");

    my @aligns = $reader->all;
    ok(@aligns, sprintf('Got all aligns (%d) from %s', scalar(@aligns), $class) );
    print $aligns[-1]->DUMP(recursive => 1);

    my $count = 0;
    foreach ( @aligns )
    {
        foreach ( @{ $_->discrepancies } )
        {
            $count++ 
        }
    };
    
    ok($count == 1668, "Got $count discreps from the alignments");

    return 1;
}

#######################################################

=pod

=head1 Synopsis

This is a test script for the Crossmatch objects

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This script is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
License for more details.

=head1 Author(s)

Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
