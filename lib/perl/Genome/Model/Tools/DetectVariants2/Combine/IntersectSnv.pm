package Genome::Model::Tools::DetectVariants2::Combine::IntersectSnv;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Combine::IntersectSnv{
    is => 'Genome::Model::Tools::DetectVariants2::Combine',
};


sub help_brief {
    "Intersect two snv variant bed files",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants combine intersect-snv --variant-file-a samtools.hq.v1.bed --variant-file-b varscan.hq.v1.bed --output-file 
EOS
}

sub help_detail {                           
    return <<EOS 
EOS
}

sub _combine_variants {
    my $self = shift;
    
    ### TODO Verify that this is sufficient for intersecting snvs.
    my $cmd = "snvcmp -a ".$self->variant_file_a." -b ".$self->variant_file_b." --hits-a ".$self->output_file;
    my $result = Genome::Sys->shellcmd( cmd => $cmd);
    return 1;
}

1;
