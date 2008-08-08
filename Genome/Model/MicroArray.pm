
package Genome::Model::MicroArray;

use strict;
use warnings;

use above "Genome";
use File::Basename;
use Sort::Naturally;

class Genome::Model::MicroArray{
    is => 'Genome::Model::ImportedVariants',
    has => [
        
        file_sample_name                => { is     => 'String',
                                             doc    => 'The sample name of interest in the genotype submission file (if there is more than one. This can be left blank if there is only one sample in the file.',
                                             is_optional => 1,
        }
    ]
};

# Returns current directory where the microarray data is housed
sub _base_directory {
    my $self = shift;

    return '/gscmnt/834/info/medseq/imported_variants_data/microarray_data/';
}

# Returns the full path to the file where the sorted microarray data should be
sub _sorted_file {
    my $self = shift;

    my $base_dir = $self->_model_directory;

    # Replace all spaces with underbars to insure proper file naming
    my $model_name = $self->name;
    $model_name =~ s/ /_/g;
    
    my $file_location = "$base_dir/sorted_$model_name.tsv";

    return $file_location; 
}

# Specialized implementation for micro array...
# Sort for genotype submission files (sort by chromosome and position)
# This uses a bunch of magic that I do not fully understand. I may be opening pandora's box.
sub _sort_input_file {
    my ($self) = @_;

    my $file = $self->_data_file;
    my $output_file_name = $self->_sorted_file;
    
    # Begin black magic for sorting the file by chrom and position
    open (DATA, $file); 
    my @list= <DATA>;
    my @sorted= @list[
    map { unpack "N", substr($_,-4) }
    sort
    map {
        my $key= $list[$_];
        $key =~ s[(\d+)][ pack "N", $1 ]ge;
        $key . pack "N", $_
    } 0..$#list
    ];
    
    # Open the output file and dump the sorted stuff
    my $output_fh = IO::File->new(">$output_file_name");

    # parse out the sample name and only copy it to the output file if it is the sample we care about
    my $sample_name = $self->file_sample_name;
    my $sample_column = 5;

    # if a sample name is defined, filter only that sample name in...
    # Also check that at least one instance of that sample is found...
    if ($sample_name) {
        my $found_any = undef;
        for my $current_line (@sorted) {
            my @line_cols = split("\t", $current_line);
            if ($line_cols[$sample_column] eq $sample_name) {
                print $output_fh $current_line;
                $found_any = 1;
            }
        }
        # warn and bomb out if nothing with specified name found
        unless ($found_any) {
            $self->error_message("No data for sample name $sample_name found!");
            return undef;
        }
    }
    # Otherwise just make sure only one sample name exists... if more than one exists bomb out and warn
    else {
        my $first_sample_name;
        for my $current_line (@sorted) {
            my @line_cols = split("\t", $current_line);
            if (!$first_sample_name) {
                $first_sample_name = $line_cols[$sample_column];
            }

            if ($line_cols[$sample_column] ne $first_sample_name) {
                my $different_sample = $line_cols[$sample_column];
                $self->error_message("Multiple sample names encountered ($different_sample, $first_sample_name) and no sample name specified!");
                return undef;
            }
            print $output_fh $current_line;
        }
    }
    
    return $output_file_name;
}

# Specialized implementation for micro array...
# This sub grabs a new line from the parameterized file handle...
# It returns the chromosome, position, ref, allele1, allele2 for that line
# This is intended to work for genotype submission files
sub _parse_line {
    my ($self, $fh) = @_;

    my $current_line;
    # Position will always be the third column
    my $position_column = 3;

    # Get lines until data is found (skip lines with '-' for allele's)
    while(!$current_line->{allele_1} || !$current_line->{allele_2}) {
        my $current_file_line = $fh->getline();

        if (!$current_file_line) {
            return undef;
        }

        $current_line->{unparsed_line} = $current_file_line;

        my @current_tabs = split("\t", $current_file_line);
        $current_line->{position} = $current_tabs[$position_column];
        # Chromosome is denoted by "C22" "C7" "CY" etc.
        ($current_line->{chromosome}) = ($current_file_line =~ m/C(\w+)/);
        # The reference allele and allele 1 will be listed as "A:G" on the line 
        ($current_line->{reference}, $current_line->{allele_1}) = ($current_file_line =~ m/([A-Z]):([A-Z])/);
        # Allele 2 will be on the line as "cns=T" if it is a het snp non ref or a homo snp...
        # if it is a het snp matching ref there will be no cns =... so set it equal to ref...
        ($current_line->{allele_2}) = ($current_file_line =~ m/cns=([A-Z])/);
        $current_line->{allele_2} ||= $current_line->{reference};
    }

    return $current_line;
}



# Hack for now to get genome-model list models to not break
sub reference_sequence_name {
    return 'N/A';
}

1;

