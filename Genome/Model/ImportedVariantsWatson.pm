
package Genome::Model::ImportedVariantsWatson;

use strict;
use warnings;

use above "Genome";

class Genome::Model::ImportedVariantsWatson {
    is => 'Genome::Model::ImportedVariants',
};

# Returns current base directory where the watson data is housed
sub _base_directory {
    my $self = shift;

    return $self->SUPER::_base_directory . '/watson/';
}

# Watson specific implementation for sort... currently does nothing
sub _sort_input_file {
    my ($self, $file) = @_;

    # Watson files do not currently need to be sorted, already sorted

    return $file;
}

# Watson specific implementation for parse
# This sub grabs a new line from the parameterized file handle...
# It returns chromosome, variant_identifier, variant_type, start, end, 
# orientation, allele_1, allele_2, reference, post_process
sub _parse_line {
    my ($self, $fh) = @_;

    my $current_file_line = $fh->getline();
    if (!$current_file_line) {
        return undef;
    }
    my @current_split = split("\t", $current_file_line);

    # Positions where data can be found (5 and 7 are unused)
    my $chromosome_col = 0;
    my $variant_identifier_col = 1;
    my $variant_type_col = 2;
    my $start_col = 3;
    my $end_col = 4;
    my $orientation_col = 6;
    my $allele_col = 8;

    my $current_line;
    $current_line->{unparsed_line} = $current_file_line;
    
    # Capture the chromosome from the file (chr1, chr2, chr22, chrY, etc.)
    ($current_line->{chromosome}) = ($current_split[$chromosome_col] =~ m/chr(\w+)/);
    
    # Capture variant identifier (supposed to be unique per variant but currently just 'JW')
    $current_line->{variant_identifier} = $current_split[$variant_identifier_col];
 
    # Grab other stuff... pretty simple
    $current_line->{variant_type} = $current_split[$variant_type_col];
    $current_line->{start} = $current_split[$start_col];
    $current_line->{end} = $current_split[$end_col];
    $current_line->{orientation} = $current_split[$orientation_col];

    # Grab the allele col and parse out useful information from it
    my $unparsed_allele_col = $current_split[$allele_col];

    # FIXME: We do not know what the ref is... are these all het snps? Or are some hom and 
    # We do not understand the notation? Wha? Who?

    # The alleles will be in the pattern A/T 
    ($current_line->{allele_1}, $current_line->{allele_2}) = ($current_file_line =~ m/([A-Z])\/([A-Z])/);

    # Set the position to start, just to be universal, these should all be SNPs
    $current_line->{position} = $current_line->{start};

    return $current_line;
}

1;
