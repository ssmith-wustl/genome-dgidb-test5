package Genome::Model::Tools::DetectVariants2::Filter::CalculatePindelReadSupport;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Filter::CalculatePindelReadSupport{
    is => 'Genome::Model::Tools::DetectVariants2::Filter',
};

sub help_brief {
    "Find the number of reads that support indel calls and their percent-strandedness",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants filter calculate-pindel-read-support
EOS
}

sub help_detail {                           
    return <<EOS 
EOS
}

sub _filter_variants {
    my $self = shift;
    #TODO Clean this up a bit. Add an option to gmt somatic calc-pindel-blah to not include dbsnp filtering
    my $result = Genome::Model::Tools::Somatic::CalculatePindelReadSupport(
                    indels_all_sequences_bed_file => $self->variant_file,
                    pindel_output_directory => $self->output_directory,
                    _output_filename => $self->output_file, );

    return 1;
}

1;
