package Genome::Model::Tools::DetectVariants2::Combine::UnionSv;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::UnionSv{
    is => 'Genome::Model::Tools::DetectVariants2::Combine',
    doc => 'Union svs into one file',
};

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants combine --variant-file-a samtools.hq.v1.bed --variant-file-b varscan.hq.v1.bed --output-file 
EOS
}


sub _combine_variants {
    my $self  = shift;

    for my $file_name qw(svs.hq tigra.out) {  #hardcoded tigra.out for now might use a generic name like sv.out later
        my @files = map{$_.'/'.$file_name}($self->input_directory_a, $self->input_directory_b);
        my $input_files = join ',', @files;
        my $output_file = $self->output_directory.'/'.$file_name;

        my $union_command = Genome::Model::Tools::Breakdancer::MergeFiles->create(
            input_files => $input_files,
            output_file => $output_file,
        );
    
        unless ($union_command->execute) {
            $self->error_message("Error executing union command");
            die $self->error_message;
        }
    }

    # When unioning, there is no "fail" really, everything should be in the hq file
    #my $lq_file = $self->output_directory.'/svs.lq';
    #`touch $lq_file`;
    return 1;
}

sub _validate_output {
    my $self = shift;
    my $variant_type = $self->_variant_type;
    my $out_file     = $self->output_directory.'/'.$variant_type.'.hq';
    my $tigra_out    = $self->output_directory.'/tigra.out';

    for my $file ($out_file, $tigra_out) {
        unless (-e $out_file) {
            die $self->error_message("Fail to find valid output file: $out_file");
        }
    }
    return 1;
}

1;
