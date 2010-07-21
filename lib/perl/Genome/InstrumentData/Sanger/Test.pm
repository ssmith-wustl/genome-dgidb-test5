package Genome::InstrumentData::Sanger::Test;
use strict;
use warnings;

#:adukes not much here, could be expanded

use base 'Test::Class';

use Test::More;

#< TESTS >#
sub test_dir {
    return '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Sanger';
}

sub test001_ : Tests(1) {
    my $self = shift;

    use_ok('Genome::InstrumentData::Sanger');

    return 1;
}

#< MOCK >#
sub create_mock_instrument_data {
    my $self = shift;

    # Number to create
    
    
    my $run_name = '01jan00.101amaa';
    my $full_path = test_dir().'/'.$run_name;
    die "Test data directory does not exist\n" unless -d $full_path;

    my $inst_data = Genome::InstrumentData::Sanger->create_mock(
        id => $run_name,
        run_name => $run_name,
        sequencing_platform => 'sanger',
        seq_id => $run_name,
        sample_name => 'unknown',
        subset_name => 1,
        library_name => 'unknown',
    )
        or die "Can't create mock sanger instrument data";

    $inst_data->set_always('full_path', $full_path);
    $inst_data->mock('resolve_full_path', sub{ return $full_path; });
    $inst_data->mock('dump_to_file_system', sub{ return 1; }); # TODO actually do something?

    return $inst_data;
}

1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

