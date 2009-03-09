package Genome::Model::Tools::Maq::Mapmerge;

use strict;
use warnings;

use Genome;
use Command;

class Genome::Model::Tools::Maq::Mapmerge {
    is => 'Genome::Model::Tools::Maq',
    has => [
            use_version => {
                            is => 'Version',
                            default_value => '0.6.8',
                            doc => "Version of maq to use",
                        },
            input_map_files => {
                           doc => 'The input map files to merge.',
                           is => 'Array',
                       },
            output_map_file => {
                           doc => 'The output map file to create.',
                           is => 'Text',
                       },
        ],
};

sub help_brief {
    'a tool for merging map files ';
}

sub help_detail {
    return <<"EOS"
Maq map files are merged together to create one larger alignment file.
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    unless ($self->input_map_files) {
        $self->error_message('Input map files are required.');
        die($self->error_message);
    }
    my $input_map_files_ref = $self->input_map_files;
    unless (ref($input_map_files_ref) && ref($input_map_files_ref) eq 'ARRAY') {
        $self->error_message('Input map files must be an array reference or list of files.');
        die($self->error_message);
    }
    my @input_map_files = @{$input_map_files_ref};
    unless (scalar(@input_map_files) > 1) {
        $self->error_message('Must have more than one input map files.');
        die($self->error_message);
    }
    for my $map_file (@input_map_files) {
        unless (-s $map_file) {
            $self->error_message('Map file '. $map_file .' not found or has zero size!');
            die($self->error_message);
        }
    }

    unless ($self->output_map_file) {
        $self->error_message('Output map file is required.');
        die($self->error_message);
    }
    if (-f $self->output_map_file) {
        $self->error_message('Output map file '. $self->output_map_file .' already exists!');
        die($self->error_message);
    }

    return $self;
}

sub execute {
    my $self = shift;

    my $input_map_files_ref = $self->input_map_files;
    my @input_map_files = @{$input_map_files_ref};
    my $cmd = $self->maq_path .' mapmerge '. $self->output_map_file .' '. join(' ',@input_map_files);
    $self->status_message('Running: '. $cmd ."\n");
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message('non-zero return value '. $rv .' for maq command '. $cmd);
        return;
    }
    return 1;
}

1;
