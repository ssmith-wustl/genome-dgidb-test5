package Genome::Model::MutationalSignificance;

use strict;
use warnings;

use Genome;

class Genome::Model::MutationalSignificance {
    is        => 'Genome::Model',
    has_input => [
        somatic_variation_models => {
            is    => 'Genome::Model::SomaticVariation',
            is_many => 1,
            doc => 'somatic variation models to evaluate',
        },
        annotation_build => {
            is => 'Genome::Model::Build::ImportedAnnotation',
            doc => 'annotation to use for roi file',
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
$self->warning_message('The logic for building a MuSiC model is not yet functional.  Contact Allison Regier');
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
        input_properties => ['processors', 'pathway_file', 'gene_covg_dir','reference_sequence','reference_build','somatic_variation_builds','build','annotation_build','pfam_output_file','cosmic_omim_output_file',
                             'clinical_correlation_output_file','mutation_relation_output_file','smg_output_file','path_scan_output_file','output_dir'],
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
    my $command_module = 'Genome::Model::MutationalSignificance::Command::PlayMusic';
    my $music_operation = $workflow->add_operation(
        name => Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string($command_module)),
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => $command_module,
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
    $command_module = 'Genome::Model::MutationalSignificance::Command::PlayMusic';
    my $merged_maf_operation = $workflow->add_operation(
        name => Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string($command_module)),
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => $command_module,
        ),
    );

    $link = $workflow->add_link(
        left_operation => $merged_maf_operation,
        left_property => 'maf_path',
        right_operation => $music_operation,
        right_property => 'maf_path',
    );
    
    # Create MAF files
 
    $command_module = 'Genome::Model::MutationalSignificance::Command::CreateMafFile';
    my $create_maf_operation = $workflow->add_operation(
        name => Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string($command_module)),
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => $command_module,
        ),
        parallel_by => 'somatic_variation_build',
    );

    $create_maf_operation->operation_type->lsf_queue($lsf_queue);
    $create_maf_operation->operation_type->lsf_project($lsf_project);
 
    $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'somatic_variation_builds',
        right_operation => $create_maf_operation,
        right_property => 'somatic_variation_build'
    );

    $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'build',
        right_operation => $create_maf_operation,
        right_property => 'build',
    );

    $link = $workflow->add_link(
        left_operation => $create_maf_operation,
        left_property => 'maf_file',
        right_operation => $merged_maf_operation,
        right_property => 'maf_files',
    );

    $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'build',
        right_operation => $merged_maf_operation,
        right_property => 'build',
    );

    #Create ROI BED file
    $command_module = 'Genome::Model::MutationalSignificance::Command::CreateROI';
    my $roi_operation = $workflow->add_operation(
        name => Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string($command_module)),
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => $command_module,
        )
    );

    $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'annotation_build',
        right_operation => $roi_operation,
        right_property => 'annotation_build',
    );

    $link = $workflow->add_link(
        left_operation => $roi_operation,
        left_property => 'roi_path',
        right_operation => $music_operation,
        right_property => 'roi_path',
    );
    #Create clinical data file
    $command_module = 'Genome::Model::MutationalSignificance::Command::CreateClinicalData',
    my $clinical_data_operation = $workflow->add_operation(
        name => Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string($command_module)),
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => $command_module,
        )
    );

    $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'build',
        right_operation => $clinical_data_operation,
        right_property => 'build',
    );

    $link = $workflow->add_link(
        left_operation => $clinical_data_operation,
        left_property => 'clinical_data_file',
        right_operation => $music_operation,
        right_property => 'clinical_data_file',
    );

    #Create BAM list
    $command_module = 'Genome::Model::MutationalSignificance::Command::CreateBamList';
    my $create_bam_list_operation = $workflow->add_operation(
        name => Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string($command_module)),
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => $command_module,
        )
    );

    $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'somatic_variation_builds',
        right_operation => $create_bam_list_operation,
        right_property => 'somatic_variation_builds',
    );

    $link = $workflow->add_link(
        left_operation => $create_bam_list_operation,
        left_property => 'bam_list',
        right_operation => $music_operation,
        right_property => 'bam_list',
    );

    my @no_dependencies = ('Proximity', 'ClinicalCorrelation', 'CosmicOmim', 'Pfam');
    my @bmr = ('Bmr::CalcCovg', 'Bmr::CalcBmr');
    my @depend_on_bmr = ('PathScan', 'Smg');
    my @depend_on_smg = ('MutationRelation');
    for my $command_name (@no_dependencies, @bmr, @depend_on_bmr, @depend_on_smg) {
        $workflow = $self->_append_command_to_workflow($command_name, $workflow)
            or return;
    }

    return $workflow;
}

sub _append_command_to_workflow {
    my $self = shift;
    my $command_name = shift;
    my $workflow = shift;
    my $command_module = join('::', 'Genome::Model::Tools::Music', $command_name);
    my $command_meta = $command_module->__meta__;
    my %links = $self->_play_music_dependencies;
    for my $property ($command_meta->_legacy_properties()) {
        next unless exists $property->{is_input} and $property->{is_input};
        my $property_name = $property->property_name;
        my $operation_name = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string($command_module));
        my $operation = $workflow->add_operation(
            name => $operation_name,
            operation_type => Workflow::OperationType::Command->create(
            command_class_name => $command_module,
            )
        );
        my $property_def = $links{$operation_name}{$property_name};
        if (!$property_def) {
            if (grep {/^$property_name$/} @{$workflow->operation_type->input_properties}) {
                $property_def = [$workflow->get_input_connector->name, $property_name];
            }
        }
        if(!$property->is_optional or defined $property_def) {
            if (!$property->is_optional and not defined $property_def) {
                die ("Non-optional property ".$property->property_name." is not provided\n");
            }
            my $from_op;
            foreach my $op ($workflow->operations) {
                if ($op->name eq $property_def->[0]) {
                    $from_op = $op;
                    last;
                }
            }
            if (!$from_op) {
                print "looking for left operation ".$property_def->[0]."\n";
                print "left property ".$property_def->[1]."\n";
                print "right operation ".$operation->name."\n";
                print "right property ".$property_name."\n";
                die ("Didn't get a from operation for the link\n");
            }
            my $link = $workflow->add_link(
            left_operation => $from_op,
            left_property => $property_def->[1],
            right_operation => $operation,
            right_property => $property_name,
            );

        }
    }
    return $workflow;
}

sub _play_music_dependencies {
    #If the input property doesn't come from directly from the input connector, specify it here
    my $self = shift;
    my $create_bam_list_operation = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string('Genome::Model::MutationalSignificance::Command::CreateBamList'));
    my $create_maf_file_operation = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string('Genome::Model::MutationalSignificance::Command::CreateMafFile'));
    my $bmr_calc_bmr_operation = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string('Genome::Model::Tools::Music::Bmr::CalcBmr'));
    my $bmr_calc_covg_operation = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string('Genome::Model::Tools::Music::Bmr::CalcCovg'));
    my $smg_operation = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string('Genome::Model::Tools::Music::Smg'));
    my $create_roi_operation = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string('Genome::Model::MutationalSignificance::Command::CreateROI'));
    my $path_scan_operation = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string('Genome::Model::Tools::Music::PathScan'));
    my $mutation_relation_operation = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string('Genome::Model::Tools::Music::MutationRelation'));
    my $proximity_operation = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string('Genome::Model::Tools::Music::Proximity'));
    my $clinical_correlation_operation = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string('Genome::Model::Tools::Music::ClinicalCorrelation'));
    my $cosmic_omim_operation = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string('Genome::Model::Tools::Music::CosmicOmim'));
    my $pfam_operation = Genome::Utility::Text::sanitize_string_for_filesystem(Genome::Utility::Text::camel_case_to_string('Genome::Model::Tools::Music::Pfam'));
    my %links = (
            $path_scan_operation => {
                bam_list => [$create_bam_list_operation, 'bam_list'],
                maf_file => [$create_maf_file_operation, 'maf_file'],
                bmr => [$bmr_calc_bmr_operation, 'bmr_output'],
                output_file => ['input connector', 'path_scan_output_file'],
            },
            $smg_operation => {
                gene_mr_file => [$bmr_calc_bmr_operation, 'gene_mr_file'],
                output_file => ['input connector', 'smg_output_file'],
            },
            $mutation_relation_operation => {
                bam_list => [$create_bam_list_operation, 'bam_list'],
                maf_file => [$create_maf_file_operation, 'maf_file'],
                output_file => ['input connector', 'mutation_relation_output_file'],
                gene_list => [$smg_operation, 'output_file'],
            },
            $bmr_calc_covg_operation => {
                roi_file => [$create_roi_operation, 'roi_file'],
                bam_list => [$create_bam_list_operation, 'bam_list'],
            },
            $bmr_calc_bmr_operation => {
                roi_file => [$create_roi_operation, 'roi_file'],
                bam_list => [$create_bam_list_operation, 'bam_list'],
                maf_file => [$create_maf_file_operation, 'maf_file'],

            },
            $proximity_operation => {
                maf_file => [$create_maf_file_operation, 'maf_file'],
            },
            $clinical_correlation_operation => {
                bam_list => [$create_bam_list_operation, 'bam_list'],
                maf_file => [$create_maf_file_operation, 'maf_file'],
                output_file => ['input connector', 'clinical_correlation_output_file'],
            },
            $cosmic_omim_operation => {
                maf_file => [$create_maf_file_operation, 'maf_file'],
                output_file => ['input connector', 'cosmic_omim_output_file'],

            },
            $pfam_operation => {
                maf_file => [$create_maf_file_operation, 'maf_file'],
                output_file => ['input connector', 'pfam_output_file'],
            },
        ); 
        return %links;
}

sub _map_workflow_inputs {
    my $self = shift;
    my $build = shift;
 
    my @inputs = ();
 
    my @builds = $build->somatic_variation_builds;
    my $base_dir = $build->data_directory;

    push @inputs, pathway_file => '/gscmnt/gc2108/info/medseq/tcga_ucec/music/endometrioid_grade_1or2_input/pathway_dbs/     KEGG_120910'; #TODO: move to params
    push @inputs, processors => 1;
    push @inputs, gene_covg_dir => $base_dir."/gene_covgs";
    push @inputs, reference_sequence => $builds[0]->reference_sequence_build->fasta_file;
    push @inputs, reference_build => "Build37";
    push @inputs, somatic_variation_builds => \@builds;
    push @inputs, build => $build;
    push @inputs, annotation_build => $build->annotation_build;
    push @inputs, pfam_output_file => $base_dir."/pfam";
    push @inputs, cosmic_omim_output_file => $base_dir."/cosmic_omim";
    push @inputs, clinical_correlation_output_file => $base_dir."/clinical_correlation";
    push @inputs, mutation_relation_output_file => $base_dir."/mutation_relation";
    push @inputs, smg_output_file => $base_dir."/smg";
    push @inputs, path_scan_output_file => $base_dir."/path_scan";
    push @inputs, output_dir => $base_dir;

    return @inputs;
}

1;
