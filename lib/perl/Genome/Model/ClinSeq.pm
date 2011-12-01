package Genome::Model::ClinSeq;

use strict;
use warnings;
use Genome;

class Genome::Model::ClinSeq {
    is => 'Genome::Model',
    has_optional_input => [
        wgs_model           => { is => 'Genome::Model::SomaticVariation' },
        exome_model         => { is => 'Genome::Model::SomaticVariation' },
        tumor_rnaseq_model  => { is => 'Genome::Model::RnaSeq' },
        normal_rnaseq_model => { is => 'Genome::Model::RnaSeq' },
    ],
    has_optional_param => [
        #someparam1 => { is => 'Number', doc => 'blah' },
        #someparam2 => { is => 'Boolean', doc => 'blah' },
        #someparam2 => { is => 'Text', valid_values => ['a','b','c'], doc => 'blah' },
    ],
    doc => 'clinial sequencing data convergence of RNASeq, WGS and exome capture data',
};

sub _initialize_profile {
    my ($self, $profile) = @_;
    $self->status_message("..initializing new profile " . $profile->__display_name__);
}

sub _resolve_subject {
    my $self = shift;
    my @subjects = $self->_infer_candidate_subjects_from_input_models();
    if (@subjects > 1) {
        $self->error_message(
            "Conflicting subjects on input models!:\n\t"
            . join("\n\t", map { $_->__display_name__ } @subjects)
        );
        return;
    }
    elsif (@subjects == 0) {
        $self->error_message("No subjects on input models?  Contact Informatics.");
        return;
    }
    return $subjects[0];
}

sub _initialize_model {
    my $self = shift;
    $self->status_message("..initializing new model " . $self->__display_name__);
}

sub _initialize_build {
    my ($self, $build) = @_;
    $self->status_message("..initializing new build " . $build->__display_name__);
}

sub _resource_requirements_for_execute_build {
    #my $self = shift;
    return "-R 'select[type==LINUX64]'";
}

sub _execute_build {
    my ($self,$build) = @_;

    my $data_directory = $build->data_directory;

    my $wgs_build           = $build->inputs(name => 'wgs_build');
    my $exome_build         = $build->inputs(name => 'exome_build');
    my $tumor_rnaseq_build  = $build->inputs(name => 'tumor_rnaseq_build');
    my $normal_rnaseq_build = $build->inputs(name => 'normal_rnaseq_build');
    
    # this input is used for testing, and when set will not actually do any work just organize params
    my $dry_run             = $build->inputs(name => 'dry_run');

    # go from the input record to the actual build it references
    for ($wgs_build, $exome_build, $tumor_rnaseq_build, $normal_rnaseq_build, $dry_run) {
        if (defined $_) { $_ = $_->value }
    }

    require Genome::Model::ClinSeq;
    my $dir = $INC{"Genome/Model/ClinSeq.pm"};
    $dir =~ s/.pm//;
    $dir .= '/original-scripts';

    my $cmd =  "$dir/clinseq.pl";
    if ($wgs_build) {
        $cmd .= ' --wgs ' . $wgs_build->model->id;
    }
    if ($exome_build) {
        $cmd .= ' --exome ' . $exome_build->model->id;
    }
    if ($tumor_rnaseq_build) {
        $cmd .= ' --tumor_rna ' . $tumor_rnaseq_build->model->id;
    }
    if ($normal_rnaseq_build) {
        $cmd .= ' --normal_rna ' . $normal_rnaseq_build->model->id;
    }

    my $common_name = $wgs_build->subject->patient->common_name;
    $cmd .= " --common_name $common_name" if $common_name;

    $cmd .= " --working '$data_directory'";
    $cmd .= " --verbose=1 --clean=1";

    if ($dry_run) {
        $build->status_message("NOT running! I _would_ have run: $cmd");
    }
    else {
        Genome::Sys->shellcmd(cmd => $cmd);
    }

    return 1;
}

sub _help_synopsis {
    my $self = shift;
    return <<"EOS"

    genome processing-profile create clin-seq --name 'November 2011 Clinical Sequencing' 

    genome model define clin-seq  -w wgsmodel -e exomemodel -t rnaseqtumormodel -n rnaseqnormalmodel -p 'November 2011 Clinical Sequencing'
    
    # auto matically builds if/when the models have a complete underlying build
EOS
}

sub _help_detail_for_profile_create {
    return <<EOS

The initial ClinSeq pipeline has no parameters.  Just use the default profile to run it.

EOS
}

sub _help_detail_for_model_define {
    return <<EOS

The ClinSeq pipeline takes four models, each of which is optional, and produces data sets potentially useful in a clinical setting.

EOS
}

sub _infer_candidate_subjects_from_input_models {
    my $self = shift;
    my %subjects;
    for my $input_model (
        $self->wgs_model,
        $self->exome_model,
        $self->tumor_rnaseq_model,
        $self->normal_rnaseq_model,
    ) {
        next unless $input_model;
        my $patient;
        if ($input_model->subject->isa("Genome::Individual")) {
            $patient = $input_model->subject;
        }
        else {
            $patient = $input_model->subject->patient;
        }
        $subjects{ $patient->id } = $patient;

        # this will only work when the subject is an original tissue
        next;

        my $tumor_model;
        if ($input_model->can("tumor_model")) {
            $tumor_model = $input_model->tumor_model;
        }
        else {
            $tumor_model = $input_model;
        }
        $subjects{ $tumor_model->subject_id } = $tumor_model->subject;
    }
    my @subjects = sort { $a->id cmp $b->id } values %subjects;
    return @subjects;
}

1;

__END__

# TODO: replace the above _execute_build with an actual workflow
# This is the code from Somatic Variation:

sub _resolve_workflow_for_build {
    my $self = shift;
    my $build = shift;

    my $operation = Workflow::Operation->create_from_xml(__FILE__ . '.xml');

    my $log_directory = $build->log_directory;
    $operation->log_dir($log_directory);

    #I think this ideally should be handled
    $operation->name($build->workflow_name);

    return $operation;
}

sub _map_workflow_inputs {
    my $self = shift;
    my $build = shift;

    my @inputs = ();

    #### This is old code from the somatic variation pipeline, replace with phenotype correlation params/inputs! #####

    # Verify the somatic model
    my $model = $build->model;

    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        die $self->error_message;
    }

    my $tumor_build = $build->tumor_build;
    my $normal_build = $build->normal_build;

    unless ($tumor_build) {
        $self->error_message("Failed to get a tumor_build associated with this somatic capture build!");
        die $self->error_message;
    }

    unless ($normal_build) {
        $self->error_message("Failed to get a normal_build associated with this somatic capture build!");
        die $self->error_message;
    }

    my $data_directory = $build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
        die $self->error_message;
    }

    my $tumor_bam = $tumor_build->whole_rmdup_bam_file;
    unless (-e $tumor_bam) {
        $self->error_message("Tumor bam file $tumor_bam does not exist!");
        die $self->error_message;
    }

    my $normal_bam = $normal_build->whole_rmdup_bam_file;
    unless (-e $normal_bam) {
        $self->error_message("Normal bam file $normal_bam does not exist!");
        die $self->error_message;
    }

    push @inputs, build_id => $build->id;

    return @inputs;
}

1;
