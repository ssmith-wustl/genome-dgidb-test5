package Genome::ProcessingProfile::ClinSeq;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::ClinSeq {
    is => 'Genome::ProcessingProfile',
    doc => "convergence of results from WGS, Exome, and RNASeq models for clinical applications",
    has_param => [
        #foo => {
        #     is => "Number",
        #     default_value => "blah",
        #     doc => "Some parameter foo.",
        #},
    ],
};

sub help_synopsis_for_create {
    my $self = shift;
    return <<"EOS"

    genome processing-profile create clin-seq --name 'November 2011 Clinical Sequencing' \

    genome model define clin-seq  -w wgsmodel -e exomemodel -r rnaseqmodel -p 'November 2011 Clinical Sequencing'
    
    # auto matically builds if/when the models have a complete underlying build
EOS
}

sub help_detail_for_create {
    return <<EOS

The initial ClinSeq pipeline has no parameters.  Just use the default profile to run it.

EOS
}

sub help_manual_for_create {
    return <<EOS
  Manual page content for this pipeline goes here.
EOS
}

sub _execute_build {
    my ($self,$build) = @_;

    my $data_directory = $build->data_directory;

    my $wgs_build   = $build->inputs(name => 'wgs_data');
    my $exome_build = $build->inputs(name => 'exome_data');
    my $rna_build   = $build->inputs(name => 'rna_data');

    # go from the input record to the actual build it references
    for ($wgs_build, $exome_build, $rna_build) {
        if (defined $_) { $_ = $_->value }
    }

    require Genome::Model::ClinSeq;
    my $dir = $INC{"Genome/Model/ClinSeq.pm"};
    $dir =~ s/.pm//;
    $dir .= '/Command/original-scripts';

    my $cmd =  "$dir/clinseq.pl";
    if ($wgs_build) {
        $cmd .= ' --wgs ' . $wgs_build->id;
    }
    if ($exome_build) {
        $cmd .= ' --exome ' . $exome_build->id;
    }
    if ($rna_build) {
        $cmd .= ' --rna ' . $rna_build->id;
    }

    my $common_name = $wgs_build->subject->patient->common_name;
    $cmd .= ' --common-name $common_name' if $common_name;

    $build->status_message("Not running! I _would_ have run: $cmd");
    #Genome::Sys->shellcmd(cmd => $cmd);
    
    return 1;
}

1;

__END__

# TODO: replace the above _execute_build with an actual workflow

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
