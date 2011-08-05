package Genome::Model::Tools::DetectVariants2::Combine::UnionCnv;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::UnionCnv{
    is => 'Genome::Model::Tools::DetectVariants2::Combine',
    doc => 'Union snvs into one file',
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'cnvs',
            doc => 'variant type that this module operates on',
        },
    ],

};

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants combine --variant-file-a samtools.hq.v1.bed --variant-file-b varscan.hq.v1.bed --output-file 
EOS
}


sub _combine_variants {
    my $self = shift;
    # TODO Figure out how to eliminate this combine step in cnv.
    #   For now, this simply copies the cnvs.hq file from input_a into the output dir.

    my $input_a = $self->input_directory_a."/cnvs.hq";
    my $input_b = $self->input_directory_b."/cnvs.hq";

    my $a = -e $input_a;
    my $b = $self->line_count( $input_b );
    if($a and not $b){
        Genome::Sys->copy_file($input_a, $self->output_directory."/cnvs.hq");
    }
    else {
        die $self->error_message("Cnv Union operation found two cnv files, but this module currently only passes one forward.");
    }
    $self->status_message("Completed copying cnvs.hq file into output directory.");
    return 1;
}

sub _generate_standard_files {
    return 1;
}

sub _validate_output {
    my $self = shift;
    return 1;
}

1;
