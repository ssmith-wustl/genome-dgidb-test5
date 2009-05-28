package Genome::Model::Tools::Maq::Mapvalidate;

use strict;
use warnings;

use Genome;
use Command;

class Genome::Model::Tools::Maq::Mapvalidate {
    is => 'Genome::Model::Tools::Maq',
    has => [
            use_version => {
                            is => 'Version',
                            default_value => '0.7.1',
                            doc => "Version of maq to use"
                        },
            map_file => {
                         doc => 'The input map file to view',
                         is => 'Text',
                     },
            output_file => {
                            doc => 'A file to write the mapvalidate output.(default=STDOUT)',
                            is => 'Text',
                            is_optional => 1,
                        },
        ],
};

sub help_brief {
    'a tool for viewing map files ';
}

sub help_detail {
    return <<"EOS"
The maq map file is binary can only be viewed as text
by running the mapvalidate command.
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    unless ($self->map_file) {
        $self->error_message('Map file is required.');
        die($self->error_message);
    }
    unless (-s $self->map_file) {
        $self->error_message('Map file '. $self->map_file .' not found or has zero size.');
        die($self->error_message);
    }
    if ($self->output_file) {
        if (-f $self->output_file) {
            $self->error_message('Output file '. $self->output_file .' already exists');
            die($self->error_message);
        }
    }

    return $self;
}

sub execute {
    my $self = shift;

    my $cmd = $self->maq_path .' mapvalidate '. $self->map_file;
    if ($self->output_file) {
        $cmd .= ' > '. $self->output_file;
    }
    my %params = (
                  cmd => $cmd,
                  input_files => [$self->map_file],
                  skip_if_output_is_present => 0,
              );
    if ($self->output_file && $self->output_file ne '/dev/null') {
        $params{output_files} = [$self->output_file];
    }
    Genome::Utility::FileSystem->shellcmd(%params);
    return 1;
}

1;
