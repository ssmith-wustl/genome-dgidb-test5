package Genome::Model::Tools::Maq::Mapcheck;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Maq::Mapcheck {
    is => 'Genome::Model::Tools::Maq',
    has => [
            use_version => {
                            is => 'Version',
                            default_value => '0.7.1',
                            doc => "Version of maq to use"
                        },
            bfa_file => {
                         doc => 'The reference sequence bfa file',
                         is => 'Text',
                     },
            map_file => {
                         doc => 'The input map file to view',
                         is => 'Text',
                     },
            output_file => {
                            doc => 'A file to write the mapview output.(default=STDOUT)',
                            is => 'Text',
                            is_optional => 1,
                        },
        ],
};

sub help_brief {
    'a tool for running mapcheck';
}

sub help_detail {
    return <<"EOS"
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    unless (-p $self->map_file) {
        unless (Genome::Sys->validate_file_for_reading($self->map_file)) {
            $self->error_message('Failed to validate map file for reading: '. $self->map_file);
            die($self->error_message);
        }
    }
    unless (Genome::Sys->validate_file_for_reading($self->bfa_file)) {
        $self->error_message('Failed to validate bfa file for reading: '. $self->bfa_file);
        die($self->error_message);
    }
    if ($self->output_file) {
        unless (Genome::Sys->validate_file_for_writing($self->output_file)) {
            $self->error_message('Failed to validate output file '. $self->output_file);
            die($self->error_message);
        }
    }

    return $self;
}

sub execute {
    my $self = shift;

    my $cmd = $self->maq_path .' mapcheck '. $self->bfa_file .' '. $self->map_file;
    my %params;
    if ($self->output_file) {
        $cmd .= ' > '. $self->output_file;
        $params{output_files} = [$self->output_file];
    }
    $params{cmd} = $cmd;
    $params{input_files} = [$self->map_file, $self->bfa_file];
    Genome::Sys->shellcmd(%params);
    return 1;
}

1;
