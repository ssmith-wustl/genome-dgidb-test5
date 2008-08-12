
package Genome::Model::ImportedVariants;

use strict;
use warnings;

use above "Genome";

class Genome::Model::ImportedVariants {
    is => 'Genome::Model',
    is_abstract => 1,
    has => [
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
    die unless $self;

    my $model_dir = $self->_model_directory();

    unless (-e $model_dir) {
        unless (system("mkdir $model_dir") == 0) {
            $self->error_message("Failed to mkdir model dir: $model_dir");
            die;
        }
    }

    my $archive_dir = $self->_archive_directory;
    unless(system("mkdir $archive_dir")==0){
        $self->error_message("Failed to mkdir $archive_dir");
        return undef;
    }

    return $self;
}

# Copies an input file to the models directory
sub add_data {
    my $self = shift;
    my $input_data = shift;

    # Grab the data file, make the appropriate directory and copy the file there with an appropriate name
    my $original_file = $input_data;
    if (!$original_file) {
        $self->error_message("Input data file not defined!");
        die;
    }

    # check if successfully made directory and copied file (return value 0)
    my $dest = $self->_data_file;

    # Move old data out of the way for new data
    $self->_archive_current_version;

    $self->status_message("Copying $original_file...");
    unless (system("cp $original_file $dest") == 0) {
        $self->error_message("Failed to cp file $original_file");
        die;
    }

    # Sort the input file
    $self->status_message("Sorting the file (if necessary)...");
    my $sorted_data_file = $self->_sort_input_file($dest);

    if (!$sorted_data_file) {
        $self->error_message("Sort input file failed!");
        die;
    }
}

# Moves old data out of the way to an archived directory
sub _archive_current_version{
    my $self = shift;
    my $current_version = $self->_current_version;
    my $current_directory = $self->_model_directory;
    my $archive_directory = $self->_archive_directory;

    my $destination_directory = "$archive_directory/$current_version";
   
    my @files = $self->_archiveable_file_names;
    if (@files){

        if (-d $destination_directory){
            $self->error_message("Archive directory for version $current_version already exists!") and die;
        }else{
            unless (system("mkdir $destination_directory") == 0){
                $self->error_message("Couldn't create archive directory $destination_directory!") and die;
            }
        }
    }
    foreach my $file (@files){
        unless (system("mv $file $destination_directory") == 0){
            $self->warning_message("error archiving $file to $destination_directory");
        }
    }
    return 1;
}

# Override me (return sub type (polyphred, etc)
sub _type{  #TODO, Will this work with MicroArray and AffiIllumina modules?
    my $self = shift;
    $self->error_message("_type is an abstract method, Genome::Model::ImportedVariants must be subclassed to work properly") and die;
}

# The directory where old data is archived
sub _archive_directory{
    my $self = shift;
    my $model_dir = $self->_model_directory;
    return "$model_dir/Archive";
}

# Returns the names of all files that should be archived
sub _archiveable_file_names{
    my $self = shift;

    my $file_to_archive = $self->_data_file;

    unless(-e $file_to_archive) {
        return;
    }

    return $self->_data_file;
}

# Returns the next version we should be on for archives
sub _current_version{
    my $self = shift;
    my $archive_dir = $self->_archive_directory;
    my @archive_folders = `ls $archive_dir`;

    # If there are no previously existing archives
    if (scalar(@archive_folders) == 0) {
        return 1;
    }

    @archive_folders = sort {$a <=> $b} @archive_folders;
    my $last_archived = pop @archive_folders;
    return $last_archived + 1;
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
# Overload this per module, probably, if we want to make subdirs for each type
sub _base_directory {
    my $self = shift;
    $self->error_message("ImportedVariants is an abstract base class, override _base directory in your subclass");
    die;
}

# Returns the current directory where this model is housed
# Should work for all submodules
sub _model_directory {
    my $self = shift;

    # Replace all spaces with underbars to insure proper directory access
    my $name = $self->name;
    $name =~ s/ /_/g;

    return $self->_base_directory . "/$name/";
}

# Returns the full path to the file where the microarray data should be
# Should work for all submodules
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
# Overload this per module
sub _sort_input_file {
    my ($self, $file) = @_;

    #my $class = $self->class;
    #$self->warning_message("_sort_input_file not implemented for $class!");

    return $file;
}

# Generic sub for parsing a line... by default warn and do nothing
# Overload this per module
sub _parse_line {
    my ($self, $fh) = @_;

    my $class = $self->class;
    $self->warning_message("_parse_line not implemented for $class!");

    return undef;
}

1;

