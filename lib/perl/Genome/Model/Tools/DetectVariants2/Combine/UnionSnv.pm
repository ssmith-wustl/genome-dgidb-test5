package Genome::Model::Tools::DetectVariants2::Combine::UnionSnv;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::UnionSnv{
    is => 'Genome::Model::Tools::DetectVariants2::Combine',
};


sub help_brief {
    "Union two snv variant bed files",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants combine --variant-file-a samtools.hq.v1.bed --variant-file-b varscan.hq.v1.bed --output-file 
EOS
}

sub help_detail {                           
    return <<EOS 
This filters out SNVs that are likely to be the result of Loss of Heterozygosity (LOH) events. The Somatic Pipeline will pass these through on its own as they are tumor variants that differ from the normal. This script defines a variant as LOH if it is homozygous, there is a heterozygous SNP at the same position in the normal and the tumor allele is one of the two alleles in the normal.  
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
