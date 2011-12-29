package Genome::Model::Tools::Sx::Trim::FarAndTrimq2;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Sx::Trim::FarAndTrimq2 {
    is => 'Genome::Model::Tools::Sx',
    has_input => [
        far_params => {
            is => "Text", 
            doc => "parameter string for far trimmer",
                    },
        trimq2_params => {
            is => "Text", 
            doc => "parameter string for trimq2",
                    },
    ],
};

sub execute{
    my $self = shift;
    my @inputs = $self->input;
    my @outputs = $self->output;

    $DB::single = 1;
    
    map {$_=~s/:.*$//}@outputs;#these outputs have :fwd :rev :frag on the end and need to be handled properly
    $self->status_message("Far and Trimq2 - inputs: ".join(", ", @inputs)." outputs: ".join(", ", @outputs));

    unless (@inputs == 2){
        die $self->error_message("only paired-end trimming is currently supported, aborting");
    }
    unless (@outputs == 3){
        die $self->error_message("must provide a fragment output file for far-and-trimq2");
    }
    
    my $far_output_dir = Genome::Sys->create_temp_directory;
    my $target = "$far_output_dir/far_trimmed";

    my $trimmer = Genome::Model::Tools::Far::Trimmer->create(
        params => $self->far_params,
        use_version => '2.0',
        source => $inputs[0],
        source2 => $inputs[1],
        target => $target,
        trim_reverse_complement => 1,
        far_output => $far_output_dir .'/far_output_report.txt',
    );
    unless ($trimmer) {
        $self->error_message('Failed to create far trimmer');
        die($self->error_message);
    }
    unless ($trimmer->execute) {
        $self->error_message('Failed to execute far');
        die($self->error_message);
    }
    my @trimmed_fastq_pathnames = glob "$target*fastq";
    unless (@trimmed_fastq_pathnames){
        die $self->error_message("Failed to get expected trimmed output files");
    }

    unless (@trimmed_fastq_pathnames == 2){
        die $self->error_message("expected 2 fastq files from far output");
    }
    
    my @params = split (/\s+|=/, $self->trimq2_params);
    for (my $i = 0; $i< $#params; $i += 2){
        $params[$i] =~ s/^--//;
        $params[$i] =~ s/-/_/g;
    }
    my $trimq2 = Genome::Model::Tools::Fastq::Trimq2::PairEnd->create(
        pair1_fastq_file => $trimmed_fastq_pathnames[0],
        pair1_out_file => $outputs[0],
        pair2_fastq_file => $trimmed_fastq_pathnames[1],
        pair2_out_file => $outputs[1],
        pair_as_frag_file => $outputs[2],
        @params
    );
    unless ($trimq2){
        die $self->error_message("could not create trimq2 trimmer");
    }
    $self->status_message("executing trimq2");
    unless ($trimq2->execute){
        die $self->error_message("Failed to execute trimq2");
    }
    unless ( 3 == grep {-e $_} @outputs){
        die $self->error_message("Failed to get output from far!");
    }
    $self->status_message("far and trimq2 trimming complete");
    return 1;
}

1;
