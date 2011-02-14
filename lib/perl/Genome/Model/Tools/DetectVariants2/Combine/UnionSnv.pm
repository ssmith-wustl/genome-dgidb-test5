package Genome::Model::Tools::DetectVariants2::Combine::UnionSnv;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::UnionSnv{
    is => 'Genome::Model::Tools::DetectVariants2::Combine',
    doc => 'Union snvs into one file',
};

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants combine --variant-file-a samtools.hq.v1.bed --variant-file-b varscan.hq.v1.bed --output-file 
EOS
}


sub _combine_variants {
    my $self = shift;
    my $snvs_a = $self->input_directory_a."/snvs.hq.bed";
    my $snvs_b = $self->input_directory_b."/snvs.hq.bed";
    my $output_file = $self->output_directory."/snvs.hq.bed";
    
    ### TODO Replace this with real unioning - this is very naive.
    my $cmd = "sort -m ".$snvs_a." ".$snvs_b." > ".$output_file;
    my $result = Genome::Sys->shellcmd( cmd => $cmd);
    my $lq_file = $self->output_directory."/snvs.lq.bed";
    `touch $lq_file`;
    return 1;
}

1;
