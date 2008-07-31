
package Genome::Model::ImportedVariants;

use strict;
use warnings;

use above "Genome";

class Genome::Model::ImportedVariants {
    is => 'Genome::Model',
    has => [
        instrument_data => { is     => 'String',
                             doc    => 'The genotype submission file to be used as microarray data. This file will be copied to the appropriate directory.',
        },
        data_file_fh    => { is          => 'IO::File',
                             doc         => 'The file handle to the micro array data file. This is set internally. Not a parameter, just a class variable.',
                             is_optional => 1,
        },
        current_line    => { is          => 'Hash',
                             doc         => 'The current line of input most recently returned from next. Not a parameter, just a class variable.',
                             is_optional => 1,
        },
    ],
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    # Grab the data file, make the appropriate directory and copy the file there with an appropriate name
    my $original_file = $self->instrument_data();
    if (!$original_file) {
        $self->error_message("Instrument data file not defined!");
        return undef;
    }

    # check if successfully made directory and copied file (return value 0)
    my $target_dir = $self->_model_directory();
    my $target_file = $self->_data_file();
    unless (-e $target_dir) {
        unless (system("mkdir $target_dir") == 0) {
            $self->error_message("Failed to mkdir $target_dir");
            return undef;
        }
    }

    $self->status_message("Copying $original_file...");
    unless (system("cp $original_file $target_file") == 0) {
        $self->error_message("Failed to cp file $original_file");
        return undef;
    }

    # Sort the input file
    $self->status_message("Sorting the file...");
    my $sorted_data_file = $self->_sort_input_file($target_file);

    if (!$sorted_data_file) {
        $self->error_message("Sort input file failed!");
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

    $current_line = $self->_parse_line($self->data_file_fh);

    $self->current_line($current_line);

    if ($current_line->{unparsed_line}) {
        return $current_line;    
    } else {
        return undef;
    }    
}

# Returns current directory where the imported variants data is housed
sub _base_directory {
    my $self = shift;

    return '/gscmnt/834/info/medseq/imported_variants_data/';
}

# Returns the current directory where this model is housed
sub _model_directory {
    my $self = shift;

    # Replace all spaces with underbars to insure proper directory access
    my $name = $self->name;
    $name =~ s/ /_/g;

    return $self->_base_directory . "/$name/";
}

# Returns the full path to the file where the microarray data should be
sub _data_file {
    my $self = shift;

    my $model_dir = $self->_model_directory;
    my $model_name = $self->name;

    # Replace spaces with underscores for a valid file name
    $model_name =~ s/ /_/g;
    
    my $file_location = "$model_dir/$model_name.tsv";

   return $file_location; 
}

# Generic sub for sorting the file... by default warn and do nothing
sub _sort_input_file {
    my ($self, $file) = @_;

    my $class = $self->class;
    $self->warning_message("_sort_input_file not implemented for $class!");
        
    return $file;
}

# Generic sub for parsing a line... by default warn and do nothing
sub _parse_line {
    my ($self, $fh) = @_;

    my $class = $self->class;
    $self->warning_message("_parse_line not implemented for $class!");
    
    return undef;
}

1;

