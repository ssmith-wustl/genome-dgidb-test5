package Genome::Model::Tools::DetectVariants2::Combine::UnionIndel;


use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::UnionIndel{
    is => 'Genome::Model::Tools::DetectVariants2::Combine',
};


sub help_brief {
    "Union two indel variant bed files",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants combine union indel --variant-file-a samtools.hq.v1.bed --variant-file-b varscan.hq.v1.bed --output-file 
EOS
}

sub help_detail {                           
    return <<EOS 
EOS
}

sub _combine_variants {
    my $self = shift;
    
    ### TODO Replace this with real unioning - this is very naive.
    my $cmd = "sort -m ".$self->variant_file_a." ".$self->variant_file_b." > ".$self->output_file;
    my $result = Genome::Sys->shellcmd( cmd => $cmd);
    return 1;
}

1;
