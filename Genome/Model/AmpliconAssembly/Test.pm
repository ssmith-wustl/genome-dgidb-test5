package Genome::Model::AmpliconAssembly::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Carp 'confess';
use Data::Dumper 'Dumper';
use File::Copy 'copy';
use File::Temp 'tempdir';
use Genome::InstrumentData::Sanger::Test;
use Genome::Model::InstrumentDataAssignment;
use Genome::ProcessingProfile::AmpliconAssembly::Test;
use Genome::Utility::FileSystem;
use Test::More;


#< REAL MODEL FOR TESTING >#
#TODO
sub test_class {
    return 'Genome::Model::AmpliconAssembly';
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
    my $pp = Genome::ProcessingProfile::AmpliconAssembly::Test->create_mock_processing_profile
        or return;

    my $model_data_dir = ( $params{use_test_dir} ) 
    ? $self->dir
    : File::Temp::tempdir(CLEANUP => 1);
    
    # Model
    my $model = Genome::Model::AmpliconAssembly->create_mock(
        id => -5000,
        genome_model_id => -5000,
        name => 'mr. mock',
        type_name => 'amplicon assembly',
        subject_name => 'mock_dna',
        subject_type => 'dna_resource_item_name',
        processing_profile_id => $pp->id,
        processing_profile => $pp,
        data_directory => $model_data_dir,
    )
        or die "Can't create mock model for amplicon assembly\n";
    
    for my $pp_param ( Genome::ProcessingProfile::AmpliconAssembly->params_for_class ) {
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
    my $build = Genome::Model::Build::AmpliconAssembly->create_mock(
        id => -10000,
        build_id => -10000,
        model_id => $model->id,
        data_directory => $model->data_directory.'/build-10000',
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
    # Genome::Model::Build::AmpliconAssembly
    $self->mock_methods(
        $build,
        'Genome::Model::Build::AmpliconAssembly',
        (qw/
            consed_directory create_directory_structure
            edit_dir chromat_dir phd_dir fasta_dir
            amplicon_fasta_types amplicon_bioseq_method_for_type fasta_file_for_type qual_file_for_type
            link_instrument_data 
            get_amplicons _determine_amplicons_in_chromat_dir_gsc 
            assembly_fasta reads_fasta processed_fasta 
            metrics_report 
            /),
    );

    $build->create_directory_structure;

    #< INSTR DATA >#
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

##########################################################

package Genome::Model::AmpliconAssembly::Report::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Genome::Model::AmpliconAssembly::Test;
use Test::More;

sub generator {
    return $_[0]->{_object};
}

sub report_name {
    my $self = shift;

    my ($pkg) = $self->test_class =~ m/Genome::Model::AmpliconAssembly::Report::(\w+)$/;

    return 'Test '.$pkg.' Report',
}

sub params_for_test_class {
    my $self = shift;

    return (
        #name => $self->report_name,
        build_id => $self->mock_model->latest_complete_build->id,
    );
}

sub mock_model {
    my $self = shift;

    unless ( $self->{_mock_model} ) {
        $self->{_mock_model} = Genome::Model::AmpliconAssembly::Test->create_mock_model(use_test_dir => 1);
    }
    
    return $self->{_mock_model};
}

sub test_01_generate_report : Test(2) {
    my $self = shift;

    can_ok($self->generator, '_generate_data');

    my $report = $self->generator->generate_report;
    ok($report, 'Generated report');
    #print Dumper([map{$report->$_} (qw/ name description date generator /)]);
    $report->save('/gscuser/ebelter/Desktop/reports', 1);

    return 1;
}

######################################################################

package Genome::Model::AmpliconAssembly::Report::AssemblyStatsTest;

use strict;
use warnings;

use base 'Genome::Model::AmpliconAssembly::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    'Genome::Model::AmpliconAssembly::Report::AssemblyStats';
}

######################################################################

package Genome::Model::AmpliconAssembly::Report::CompositionTest;

use strict;
use warnings;

use base 'Genome::Model::AmpliconAssembly::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    'Genome::Model::AmpliconAssembly::Report::Composition';
}

######################################################################

package Genome::Model::AmpliconAssembly::Report::SummaryTest;

use strict;
use warnings;

use base 'Genome::Model::AmpliconAssembly::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    'Genome::Model::AmpliconAssembly::Report::Summary';
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
