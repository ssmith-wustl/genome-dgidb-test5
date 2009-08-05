package Genome::Model::ReferenceAlignment::Test;

use strict;
use warnings;

use Genome;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use File::Copy 'copy';
use File::Temp 'tempdir';
use Genome::InstrumentData::Sanger::Test;
use Genome::Model::Build::ReferenceAlignment::Solexa;
use Genome::Model::InstrumentDataAssignment;
use Genome::ProcessingProfile::ReferenceAlignment::Test;
use Genome::Utility::FileSystem;
use Test::More;

sub test_class {
    return 'Genome::Model::ReferenceAlignment';
}

#< MOCK ># 
sub get_mock_model_id {
    return -5000;
}

sub get_mock_build_id {
    return -50001;
}

sub create_mock_model {
    my $self = shift;

    # Processing profile
    my $pp = Genome::ProcessingProfile::ReferenceAlignment::Test->create_mock_processing_profile
        or return;

    #my $data_dir = File::Temp::tempdir(DIR => $self->test_dir, CLEANUP => 0);
    #my $data_dir = File::Temp::tempdir(CLEANUP => 1);
    my $data_dir = $self->dir;
    die "Can't find reference alignment model data directory\n" unless -d $data_dir;

    # Model
    my $model = Genome::Model::ReferenceAlignment->create_mock(
        id => get_mock_model_id(),
        genome_model_id =>get_mock_model_id(),
        name => 'mr. ref al',
        subject_name => 'mock_dna',
        subject_type => 'dna_resource_item_name',
        processing_profile_id => $pp->id,
        processing_profile => $pp,
        data_directory => $data_dir,
    )
        or die "Can't create mock model for amplicon assembly\n";
    
    for my $pp_param ( $pp->params_for_class ) {
        $model->set_always($pp_param, $pp->$pp_param);
    }

    #< Build ># /gscmnt/sata835/info/medseq/model_data/2733662090/build93293206
    my $build_id = get_mock_build_id();
    my $build_dir = $self->dir.'/build'.$build_id;
    my $build_reports_dir = $build_dir.'/reports';
    my $build = Genome::Model::Build->create_mock(
        id => $build_id,
        build_id => $build_id,
        model_id => $model->id,
        data_directory => $build_dir,
    );
    $build->set_always('model', $model);
    $build->set_always('model_id', $model->id);
    $build->set_always('build_status', 'Succeeded'); # mock event for this?
    $build->set_always('date_completed', '20-OCT-08 05.49.49.000000 PM'); # mock event for this?
    Genome::Utility::TestBase->mock_methods(
        $build,
        'Genome::Model::Build',
        (qw/ resolve_data_directory resolve_reports_directory /),
    );
    Genome::Utility::TestBase->mock_methods(
        $build,
        'Genome::Model::Build::ReferenceAlignment::Solexa',
        (qw/ snp_related_metric_directory /),
    );
    $build->set_list('_variant_list_files', glob($build->snp_related_metric_directory.'/snps_*'));

    # mock build info for model
    $model->set_list('builds', $build);
    Genome::Utility::TestBase->mock_methods(
        $model,
        'Genome::Model',
        (qw/ completed_builds last_complete_build last_complete_build_id /),
    );
    Genome::Utility::TestBase->mock_methods(
        $model,
        'Genome::Model::ReferenceAlignment',
        (qw/ 
            complete_build_directory 
            _filtered_variants_dir 
            gold_snp_file 
        /),
    );
    

    return $model;
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
