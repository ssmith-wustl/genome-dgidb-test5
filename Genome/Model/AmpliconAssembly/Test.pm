package Genome::Model::AmpliconAssembly::Test;

use strict;
use warnings;

use base 'Test::Class';

use File::Copy 'copy';
use File::Temp 'tempdir';
use Genome::InstrumentData::Sanger::Test;
use Genome::Model::InstrumentDataAssignment;
use Genome::ProcessingProfile::AmpliconAssembly::Test;
use Genome::Utility::FileSystem;
use Test::More;

#< DIR >#
sub test_dir {
    return '/gsc/var/cache/testsuite/data/Genome-Model-AmpliconAssembly';
}

sub _test_dir_for_type {
    die "No type to get test dir\n" if not defined $_[0] or $_[0] eq __PACKAGE__;
    return test_dir().'/'.$_[0];
}

#< MOCK ># 
sub create_mock_model {
    my $self = shift;

    # Processing profile
    my $pp = Genome::ProcessingProfile::AmpliconAssembly::Test->create_mock_processing_profile
        or return;

    #my $data_dir = File::Temp::tempdir(DIR => $self->test_dir, CLEANUP => 0);
    my $data_dir = File::Temp::tempdir(CLEANUP => 1);
    die "Can't make temp data directory for mock model\n" unless -d $data_dir;

    # Model
    my $model = Genome::Model::AmpliconAssembly->create_mock(
        id => -5000,
        genome_model_id => -5000,
        name => 'mr. mock',
        subject_name => 'mock_dna',
        subject_type => 'dna_resource_item_name',
        processing_profile_id => $pp->id,
        processing_profile => $pp,
        data_directory => $data_dir,
    )
        or die "Can't create mock model for amplicon assembly\n";
    for my $pp_param ( Genome::ProcessingProfile::AmpliconAssembly->params_for_class ) {
        $model->set_always($pp_param, $pp->$pp_param);
    }
    for my $dir_type ( Genome::Consed::Directory->directories ) {
        my $dir = $data_dir.'/'.$dir_type; 
        $model->set_always($dir_type, $dir);
        mkdir $dir
            or die "Can't make directory ($dir): $!\n";
    }
    $model->mock(
        'amplicons',
        sub{  
            my $dh = Genome::Utility::FileSystem->open_directory( $model->chromat_dir )
                or return;

            my %amplicons;
            while ( my $scf = $dh->read ) {
                next if $scf =~ m#^\.#;
                $scf =~ s#\.gz##;
                $scf =~ /^(.+)\.[bg]\d+$/
                    or next;
                push @{$amplicons{$1}}, $scf;
            }
            $dh->close;

            return \%amplicons;
        },
    );

    #< FILES >#
    for my $type (qw/ assembly reads processed assembly.confirmed assembly.unconfirmed /) {
        my $method = $type.'_fasta';
        $model->set_always($method, sprintf('%s/%s.%s.fasta', $data_dir, $model->subject_name, $type));
    }
    $model->set_always('metrics_file',  sprintf('%s/%s.metrics.txt', $data_dir, $model->subject_name));

    return $model;
}

sub create_mock_model_with_instrument_data {
    my $self = shift;

    my $model = $self->create_mock_model
        or return;

    my $inst_data = Genome::InstrumentData::Sanger::Test->create_mock_instrument_data; # this dies if no workee
    my $ida = Genome::Model::InstrumentDataAssignment->create_mock(
        id => -5000,
        model_id => $model->id,
        instrument_data_id => $inst_data->id,
        first_build_id => undef,
    )
        or die "Can't create mock instrument data assignment\n";
    $ida->set_always('model_id', $model);
    $ida->set_always('instrument_data', $inst_data);
    $ida->mock(
        'first_build_id', sub { 
            my ($ida, $fbi) = @_;
            $ida->{first_build_id} = $fbi if defined $fbi;
            return $ida->{first_build_id}; 
        },
    );
    $model->set_always('instrument_data', ( $inst_data ));
    $model->set_always('instrument_data_assignments', ( $ida ));

    return $model;
}

#< COPY DATA >#
sub copy_dirs_to_model {
    my ($self, $model, @dirs) = @_;

    die "Need dir types to copy from\n" unless @dirs;

    for my $dir ( @dirs ) {
        my $dest = ( $model->can($dir) )
        ? $model->$dir
        : $model->data_directory;
        $self->_copy_dir(_test_dir_for_type($dir), $dest)
            or return;
    }

    return 1;
}

sub _copy_dir {
    my ($self, $source, $dest) = @_;

    my $dh = Genome::Utility::FileSystem->open_directory($source)
        or return;

    while ( my $file = $dh->read ) {
        next if $file =~ m#^\.#;
        File::Copy::copy("$source/$file", $dest)
            or die "Can't copy ($source/$file) to ($dest): $!\n";
    }

    return 1;

}

#< REAL MODEL FOR TESTING >#

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

