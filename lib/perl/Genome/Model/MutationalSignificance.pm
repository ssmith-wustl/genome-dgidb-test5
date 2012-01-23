package Genome::Model::MutationalSignificance;

use strict;
use warnings;
BEGIN { $INC{"Genome/Model/Build/MutationalSignificance.pm"} = 1; $INC{"Genome/ProcessingProfile/MutationalSignificance.pm"} = 1; $INC{"Genome/Model/Command/Define/MutationalSignificance.pm"} = 1; };
use Genome;

# DEFAULTS
my $DEFAULT_CLUSTERS = '5000';
my $DEFAULT_CUTOFF = '2';
my $DEFAULT_ZENITH = '5';
my $DEFAULT_MIN_DEPTH = '1';
my $DEFAULT_BIN 	= '17_70';


class Genome::Model::MutationalSignificance {
    is        => 'Genome::Model',
    has_input => [
        somatic_variation_model => {
            is    => 'Genome::Model::SomaticVariation',
            is_many => 1,
            doc => 'somatic variation models to evaluate',
        },
    ],
    has_param => [
	],
};

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
TO DO
EOS
}

sub help_detail_for_create_profile {
    return <<EOS
  TO DO
EOS
}

sub help_manual_for_define_model {
    return <<EOS
TO DO
EOS
}

sub _resolve_workflow_for_build {

    # This is called by Genome::Model::Build::start()
    # Returns a Workflow::Operation
    # By default, builds this from stages(), but can be overridden for custom workflow.
    my $self = shift;
    my $build = shift;
    my $lsf_queue = shift; # TODO: the workflow shouldn't need this yet
    my $lsf_project = shift;
     
    if (!defined $lsf_queue || $lsf_queue eq '' || $lsf_queue eq 'inline') {
        $lsf_queue = 'apipe';
    }
    if (!defined $lsf_project || $lsf_project eq '') {
        $lsf_project = 'build' . $build->id;
    }
     

    my $workflow = Workflow::Model->create(
        name => $build->workflow_name,
        input_properties => ['somatic_variation_builds','build_id'],
        output_properties => ['smg_result','pathscan_result','mrt_result','pfam_result','proximity_result',
                              'cosmic_result','cct_result'],
    );

    my $log_directory = $build->log_directory;
    $workflow->log_dir($log_directory);
 
    my $input_connector = $workflow->get_input_connector;
    my $output_connector = $workflow->get_output_connector;

    # For now, just get the ultra-high confidence variants.
    # TODO: figure out how to add in the manual review ones

    #Run Music
    my $music_operation = $workflow->add_operation(
        name => 'Play MuSiC',
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => 'Genome::Model::MutationalSignificance::Command::PlayMusic',
        )
    );

    $music_operation->operation_type->lsf_queue($lsf_queue);
    $music_operation->operation_type->lsf_project($lsf_project);

    my $link = $workflow->add_link(
        left_operation => $music_operation,
        left_property => 'proximity_result',
        right_operation => $output_connector,
        right_property => 'proximity_result',
    );
    $link = $workflow->add_link(
        left_operation => $music_operation,
        left_property => 'pfam_result',
        right_operation => $output_connector,
        right_property => 'pfam_result',
    );
    $link = $workflow->add_link(
        left_operation => $music_operation,
        left_property => 'mrt_result',
        right_operation => $output_connector,
        right_property => 'mrt_result',
    );
    $link = $workflow->add_link(
        left_operation => $music_operation,
        left_property => 'pathscan_result',
        right_operation => $output_connector,
        right_property => 'pathscan_result',
    );
    $link = $workflow->add_link(
        left_operation => $music_operation,
        left_property => 'smg_result',
        right_operation => $output_connector,
        right_property => 'smg_result',
    );
    $link = $workflow->add_link(
        left_operation => $music_operation,
        left_property => 'cosmic_result',
        right_operation => $output_connector,
        right_property => 'cosmic_result',
    );
    $link = $workflow->add_link(
        left_operation => $music_operation,
        left_property => 'cct_result',
        right_operation => $output_connector,
        right_property => 'cct_result',
    );

    #Merge MAF files
    my $merged_maf_operation = $workflow->add_operation(
        name => 'Merge MAF files',
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => 'Genome::Model::MutationalSignificance::Command::MergeMafFiles',
        ),
    );

    $link = $workflow->add_link(
        left_operation => $merged_maf_operation,
        left_property => 'maf_path',
        right_operation => $music_operation,
        right_property => 'maf_path',
    );
    
    # Create MAF files
 
    my $create_maf_operation = $workflow->add_operation(
        name => 'Create MAF file for sample',
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => 'Genome::Model::MutationalSignificance::Command::CreateMafFile',
        ),
        parallel_by => 'model',
    );

    $create_maf_operation->operation_type->lsf_queue($lsf_queue);
    $create_maf_operation->operation_type->lsf_project($lsf_project);
 
    $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'somatic_variation_builds',
        right_operation => $create_maf_operation,
        right_property => 'model'
    );

    $link = $workflow->add_link(
        left_operation => $create_maf_operation,
        left_property => 'model_output',
        right_operation => $merged_maf_operation,
        right_property => 'array_of_model_outputs',
    );

    #Create ROI BED file
    my $roi_operation = $workflow->add_operation(
        name => 'Create ROI BED file',
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => 'Genome::Model::MutationalSignificance::Command::CreateROI',
        )
    );

    $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'build_id',
        right_operation => $roi_operation,
        right_property => 'build_id',
    );

    $link = $workflow->add_link(
        left_operation => $roi_operation,
        left_property => 'roi_path',
        right_operation => $music_operation,
        right_property => 'roi_path',
    );
    #Create clinical data file
    my $clinical_data_operation = $workflow->add_operation(
        name => 'Create clinical data file',
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => 'Genome::Model::MutationalSignificance::Command::CreateClinicalData',
        )
    );

    $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'build_id',
        right_operation => $clinical_data_operation,
        right_property => 'build_id',
    );

    $link = $workflow->add_link(
        left_operation => $clinical_data_operation,
        left_property => 'clinical_data_file',
        right_operation => $music_operation,
        right_property => 'clinical_data_file',
    );

    #Create BAM list
    my $bam_list_operation = $workflow->add_operation(
        name => 'Create BAM list',
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => 'Genome::Model::MutationalSignificance::Command::CreateBamList',
        )
    );

    $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'build_id',
        right_operation => $bam_list_operation,
        right_property => 'build_id',
    );

    $link = $workflow->add_link(
        left_operation => $bam_list_operation,
        left_property => 'bam_list',
        right_operation => $music_operation,
        right_property => 'bam_list',
    );

    return $workflow;
}

sub _map_workflow_inputs {
    my $self = shift;
    my $build = shift;
 
    my @inputs = ();
 
    my @builds = $build->somatic_variation_build;

    push @inputs, somatic_variation_builds => \@builds;
    push @inputs, build_id => $build->id;

    return @inputs;
}

1;
