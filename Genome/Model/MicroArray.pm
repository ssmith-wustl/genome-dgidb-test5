
package Genome::Model::MicroArray;

use strict;
use warnings;

use above "Genome";
use GSCApp;
use File::Basename;
use Sort::Naturally;

class Genome::Model::MicroArray{
    is => 'Genome::Model',
    has => [
        genotype_submission_file        => { is     => 'String',
                                             doc    => 'The genotype submission file to be used as microarray data. This file will be copied to the appropriate directory.',
        }
    ],
    has_optional => [
        data_file_fh                    => { is     => 'IO::File',
                                             doc    => 'The file handle to the micro array data file. This is set internally. Not a parameter, just a class variable.',
        },
        current_line                    => { is     => 'Hash',
                                             doc    => 'The current line of input most recently returned from next. Not a parameter, just a class variable.',
        },
        file_sample_name                => { is     => 'String',
                                             doc    => 'The sample name of interest in the genotype submission file (if there is more than one. This can be left blank if there is only one sample in the file.',
        }
    ]
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    # Grab the data file, make the appropriate directory and copy the file there with an appropriate name
    my $original_file = $self->genotype_submission_file();
    if (!$original_file) {
        $self->error_message("Genotype submission file not defined!");
        return undef;
    }

    # check if successfully made directory and copied file (return value 0)
    my $target_dir = $self->_base_directory();
    my $target_file = $self->_data_file();
    unless (-e $target_dir) {
        unless (system("mkdir $target_dir") == 0) {
            $self->error_message("Failed to mkdir $target_dir");
            return undef;
        }
    }

    unless (-e $target_file) {
        unless (system("cp $original_file $target_file") == 0) {
            $self->error_message("Failed to cp file $original_file");
            return undef;
        }
    }

    # Sort the genotype submission file
    my $sorted_data_file = $self->_sort_genotype_submission_file($target_file);

    if (!$sorted_data_file) {
        $self->error_message("Sort genotype submission file failed!");
        return undef;
    }

    # Set up the class level file handle to the micro array data file (sorted version)
    my $data_file_fh = IO::File->new($sorted_data_file);
    $self->data_file_fh($data_file_fh);

    return $self;
}
# returns the parsed from a single line of the micro array data file
# returns chrom, pos, ref, allele1, allele2, or undef if no more lines left on fh
sub get_next_line {
    my $self = shift;
    my $current_line;

    ($current_line->{unparsed_line}, $current_line->{chromosome}, $current_line->{position}, $current_line->{reference}, $current_line->{allele_1}, $current_line->{allele_2})
        = $self->_parse_genotype_submission_line($self->data_file_fh);

    $self->current_line($current_line);

    if ($current_line->{unparsed_line}) {
        return $current_line;    
    } else {
        return undef;
    }    
}

# Returns current directory where the microarray data is housed
sub _base_directory {
    my $self = shift;

    # Replace all spaces with underbars to insure proper directory access
    my $name = $self->name;
    $name =~ s/ /_/g;

    return '/gscmnt/834/info/medseq/microarray_data/'.$name;
}

# Returns the full path to the file where the microarray data should be
sub _data_file {
    my $self = shift;

    my $base_dir = $self->_base_directory;
    my $model_name = $self->name;
    my $file_location = "$base_dir/$model_name.tsv";

   return $file_location; 
}

# Sort for genotype submission files (sort by chromosome and position)
# This uses a bunch of magic that I do not fully understand. I may be opening pandora's box.
sub _sort_genotype_submission_file {
    my ($self, $file) = @_;

    my $output_file_name = $file . "_sorted";

    # if it is already sorted, just return the sorted name
    if (-s $output_file_name) {
        return $output_file_name;
    }
    
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

# This sub grabs a new line from the parameterized file handle...
# It returns the chromosome, position, ref, allele1, allele2 for that line
# This is intended to work for genotype submission files
sub _parse_genotype_submission_line {
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

1;

