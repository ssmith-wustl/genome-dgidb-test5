package Genome::Model::DeNovoAssembly::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Carp 'confess';
use Data::Dumper 'Dumper';
use File::Copy 'copy';
use File::Temp 'tempdir';
require Genome::InstrumentData::Solexa::Test;
require Genome::ProcessingProfile::DeNovoAssembly::Test;
require Genome::Utility::FileSystem;
use Test::More;

#< Stuff for Real Test >#
sub test_class {
    return 'Genome::Model::DeNovoAssembly';
}

sub params_for_test_class {
    return (
        subject_name => 'dna',
        subject_type => 'dna_resource_item_name',
    );
}

sub required_attrs {
    return (qw/ subject_type /);
}

#< DIR >#
sub _test_dir_for_type {
    return $_[0]->dir.'/build-10000/'.$_[1];
}

#< MOCK ># 
sub create_mock_model {
    my ($self, %params) = @_;

    # Processing profile
    my $pp = Genome::ProcessingProfile::DeNovoAssembly::Test->create_mock_processing_profile(
        assembler_name => 'velvet',
        sequencing_platform => 'solexa',
    )
        or return;

    my $model_data_dir = ( $params{use_test_dir} ) 
    ? $self->dir
    : File::Temp::tempdir(CLEANUP => 1);
    
    # Model
    my $model = Genome::Model::DeNovoAssembly->create_mock(
        id => -5000,
        genome_model_id => -5000,
        name => 'duh novo',
        type_name => 'de novo assembly',
        subject_name => 'mock_dna',
        subject_type => 'dna_resource_item_name',
        processing_profile_id => $pp->id,
        processing_profile => $pp,
        data_directory => $model_data_dir,
    )
        or die "Can't create mock model for de novo assembly\n";
    
    for my $pp_param ( Genome::ProcessingProfile::DeNovoAssembly->params_for_class ) {
	#SKIP PP PARAMS THAT ARE NOT SPECIFIED FOR CLASS
	#EG, VELVET-SOLEXA DO NOT HAVE PREPROCESS PARAMS
	next unless exists $pp->{'_'.$pp_param};
        $model->set_always($pp_param, $pp->$pp_param);
    }

    $self->mock_methods(
        $model,
        'Genome::Model',
        (qw/
            running_builds build_event 
            current_running_build_id
            last_complete_build_id last_complete_build
            /),
    );

    # Build
    my $build = Genome::Model::Build::DeNovoAssembly->create_mock(
        id => -11100,
        build_id => -11100,
        model_id => $model->id,
        data_directory => $model->data_directory.'/build-11100',
    );
    mkdir $build->data_directory;
    $build->set_always('model', $model);
    $model->set_list('builds', $build);
    $model->set_always('latest_complete_build', $build);
    $model->mock('current_running_build', sub{ Genome::Model::current_running_build(@_); } );

    # Genome::Model::Build
    $self->mock_methods(
        $build,
        'Genome::Model::Build',
        (qw/
            build_events build_event build_status
            add_report resolve_reports_directory
            /),
    );
    # Accessors
    $self->mock_accessors(
        $build,
        (qw/
            event_status date_scheduled date_completed
            /),
    );
#   Genome::Model::Build::DeNovoAssembly
    $self->mock_methods(
       $build,
       'Genome::Model::Build::DeNovoAssembly',
       (qw/ velvet_fastq_file
           /),
    );

    #< INSTR DATA >#
    my $inst_data = Genome::InstrumentData::Solexa::Test->create_mock_instrument_data; # this dies if no workee
    my $ida = Genome::Model::InstrumentDataAssignment->create_mock(
        id => -11100,
        model_id => $model->id,
        instrument_data_id => $inst_data->id,
        first_build_id => undef,
    )
        or die "Can't create mock instrument data assignment\n";
    $ida->set_always('model_id', $model);
    $ida->set_always('instrument_data', $inst_data);
    $ida->mock(
        'first_build_id', sub{ 
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
sub copy_test_dir {
    my ($self, $subdir, $dest) = @_;

    Genome::Utility::FileSystem->validate_existing_directory($dest)
        or confess;
    
    my $source = $self->_test_dir_for_type($subdir);
    my $dh = Genome::Utility::FileSystem->open_directory($source)
        or confess;

    while ( my $file = $dh->read ) {
        next if $file =~ m#^\.#;
        File::Copy::copy("$source/$file", $dest)
            or die "Can't copy ($source/$file) to ($dest): $!\n";
    }

    return 1;
}

1;

=pod

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/DeNovoAssembly/Test.pm $
#$Id: Test.pm 47490 2009-06-02 17:06:28Z ebelter $
