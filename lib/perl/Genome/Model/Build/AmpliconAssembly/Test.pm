######################################################################

package Genome::Model::Build::AmpliconAssembly::AmpliconTest;
#:adukes check

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub amplicon {
    return $_[0]->{_object};
}

sub test_class {
    'Genome::Model::Build::AmpliconAssembly::Amplicon';
}

sub params_for_test_class {
    return (
        name => 'HMPB-aad13e12',
        directory => '/gsc/var/cache/testsuite/data/Genome-Model-AmpliconAssembly/edit_dir',
        reads => [qw/ HMPB-aad13e12.b1 HMPB-aad13e12.b2 HMPB-aad13e12.b3 HMPB-aad13e12.b4 HMPB-aad13e12.g1 HMPB-aad13e12.g2 /],
    );
}

sub invalid_params_for_test_class {
    return (
        directory => 'does_not_exist',
    );
}

sub test01_accessors : Tests {
    my $self = shift;

    my $amplicon = $self->amplicon;

    my %params = $self->params_for_test_class;
    for my $attr ( keys %params ) {
        my $method = 'get_'.$attr;
        is_deeply($amplicon->$method, $params{$attr}, "Got $attr");
    }

    return 1;
}

sub test02_bioseq : Tests {
    my $self = shift;

    my $amplicon = $self->amplicon;
    ok($amplicon->get_bioseq, 'Got bioseq');
    is($amplicon->get_bioseq_source, 'assembly', 'Got source - assembly');
    is($amplicon->was_assembled_successfully, 1, 'Assembled successfully');
    is($amplicon->is_bioseq_oriented, 0, 'Not oriented');
 
    return 1;
}

sub test03_reads : Tests {
    my $self = shift;

    my $amplicon = $self->amplicon;
    my %params = $self->params_for_test_class;
    my $attempted_reads = $params{reads};
    
    my $assembled_reads = $amplicon->get_assembled_reads;
    is_deeply($assembled_reads, $attempted_reads, 'Got source');
    is($amplicon->get_assembled_read_count, scalar(@$assembled_reads), 'Got source');
    my $read_bioseq = $amplicon->get_bioseq_for_raw_read($attempted_reads->[2]);
    is($read_bioseq->id, $attempted_reads->[2], 'Got read bioseq for '.$attempted_reads->[2]);
    my $processed_bioseq = $amplicon->get_bioseq_for_processed_read($attempted_reads->[4]);
    is($processed_bioseq->id, $attempted_reads->[4], 'Got processed bioseq for '.$attempted_reads->[4]);
    
    return 1;
}

sub test03_files {#: Tests {
    my $self = shift;

    #TODO
    
    return 1;
}

######################################################################

1;

=pod

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
