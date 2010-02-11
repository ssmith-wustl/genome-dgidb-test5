package Genome::Model::Event::Build::ReferenceAlignment::AnnotateAdaptor;

use strict;
use warnings;
use IO::File;
use File::Copy;
use DateTime;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::AnnotateAdaptor{
    is => ['Genome::Model::Event'],
    has => [
    analysis_base_path => {
        doc => "the path at which all analysis output is stored",
        calculate_from => ['build'],
        calculate      => q|
        return $build->snp_related_metric_directory;
        |,
        is_constant => 1,
    },
    filtered_snp_output_file => {
        doc => "",
        calculate_from => ['analysis_base_path'],
        calculate      => q|
        return $analysis_base_path .'/filtered.indelpe.snps';
        |,
    },
    pre_annotation_filtered_snp_file => {
        doc => "",
        calculate_from => ['analysis_base_path'],
        calculate      => q|
        return $analysis_base_path .'/filtered.indelpe.snps.pre_annotation';
        |,
    },  
    ],
};

sub execute{
    my $self = shift;

    my $fh = IO::File->new(">> /gscuser/adukes/build/status");
    my $dt = DateTime->now();
    $fh->print("####################\n$dt\nExecuting Annotate Adaptor");
    $fh->print('analysis_base_path: '.$self->analysis_base_path."\n");
    $fh->print('filtered_snp_output_file: '. $self->filtered_snp_output_file."\n");
    $fh->print('pre_annotation_filtered_snp_file '. $self->pre_annotation_filtered_snp_file."\n");
    
    
    unless( $self->check_for_existence($self->filtered_snp_output_file) ){
        $self->error_message("filtered snp output file from find variations step doesn't exist");
        return;
    } 

    unless(-s $self->filtered_snp_output_file) {
        copy($self->filtered_snp_output_file, $self->pre_annotation_filtered_snp_file);
    } else {
        my $adaptor = Genome::Model::Tools::Annotate::Adaptor::Sniper->create(
            somatic_file => $self->filtered_snp_output_file,
            output_file => $self->pre_annotation_filtered_snp_file,
            skip_if_output_present => 1,
        );
    
        my $rv = $adaptor->execute;
        unless ($rv){
            $self->error_message("Adapting filtered snp output file for annotation failed");
            return;
        }
    }
    
    return 1;

}

1;
