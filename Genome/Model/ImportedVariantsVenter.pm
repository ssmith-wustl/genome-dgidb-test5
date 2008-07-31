
package Genome::Model::ImportedVariantsVenter;

use strict;
use warnings;

use above "Genome";

class Genome::Model::ImportedVariantsVenter {
    is => 'Genome::Model::ImportedVariants',
};

# Returns current base directory where the Venter data is housed
sub _base_directory {
    my $self = shift;

    return $self->SUPER::_base_directory . '/venter/';
}

# Venter specific implementation for sort... currently does nothing
sub _sort_input_file {
    my ($self, $file) = @_;

    # Venter files do not currently need to be sorted, already sorted

    return $file;
}

# Venter specific implementation for parse
# This sub grabs a new line from the parameterized file handle...
# It returns chromosome, variant_identifier, variant_type, start, end, 
# orientation, allele_1, allele_2, reference, post_process
sub _parse_line {
    my ($self, $fh) = @_;

    my $current_line;

    # TODO: Check for if there is a previously encountered MNP in queue here
    # load it into the hashref and return it if so
    
    # Keep getting lines until we've gotten a line we can interpret
    while (!$current_line->{allele_1} || !$current_line->{allele_2}) {
        my $current_file_line = $fh->getline();
        if (!$current_file_line) {
            return undef;
        }
        my @current_split = split("\t", $current_file_line);

        # Positions where data can be found (5 is unused)
        my $chromosome_col = 0;
        my $variant_identifier_col = 1;
        my $variant_type_col = 2;
        my $start_col = 3;
        my $end_col = 4;
        my $orientation_col = 6;
        my $allele_col = 7;
        my $post_process_col = 8;

        $current_line->{unparsed_line} = $current_file_line;

        # Grab other stuff... pretty simple
        $current_line->{chromosome} = $current_split[$chromosome_col];
        $current_line->{variant_identifier} = $current_split[$variant_identifier_col];
        $current_line->{variant_type} = $current_split[$variant_type_col];
        $current_line->{start} = $current_split[$start_col];
        $current_line->{end} = $current_split[$end_col];
        $current_line->{orientation} = $current_split[$orientation_col];
        $current_line->{post_process} = $current_split[$post_process_col];

        # Grab the allele col and parse out useful information from it
        my $unparsed_allele_col = $current_split[$allele_col];

        # Figure out of this is labeled as het or hom and deal accordingly
        # The alleles will be in the pattern A/T 
        if ($current_line->{variant_type} eq 'heterozygous_SNP') {
            ($current_line->{allele_1}, $current_line->{allele_2}) = ($current_file_line =~ m/([A-Z])\/([A-Z])/);
            # Set the position to start, just to be universal
            $current_line->{position} = $current_line->{start};
        } elsif ($current_line->{variant_type} eq 'homozygous_SNP') {
            ($current_line->{reference}, $current_line->{allele_1}) = ($current_file_line =~ m/([A-Z])\/([A-Z])/);
            $current_line->{allele_2} = $current_line->{allele_1};
            # Set the position to start, just to be universal
            $current_line->{position} = $current_line->{start};
        } elsif ($current_line->{variant_type} eq 'heterozygous_MNP') {
            # TODO : deal with "MNP's"
            # Could make a class level list... a queue of sorts... stuff MNP's in there when they are
            # encountered... check to make sure its empty before getting a new line... if not
            # empty just shift off of there...
        }

        #TODO: Deal with other stuff... do I just toss out indels? Copy to a log file maybe?
    }

    return $current_line;
}

1;
