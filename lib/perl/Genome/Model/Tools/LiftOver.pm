package Genome::Model::Tools::LiftOver;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::LiftOver {
    is => 'Command',
    has => [
        source_file => {
            is => 'Text',
            doc => 'The file to be translated',
        },
        destination_file => {
            is => 'Text',
            doc => 'Where to output the translated file',
        },
        chain_file => {
            is => 'Text',
            doc => 'The liftOver "chain" file that maps from the source reference to the destination reference',
        },
    ],
    has_optional => [
        unmapped_file => {
            is => 'Text',
            doc => 'Where to put the unmapped input',
            is_optional => 1,
        },
        allow_multiple_output_regions => {
            is => 'Boolean',
            doc => 'Whether or not to allow multiple output regions',
            default => '0',
        },
        file_format => {
            is => 'Text',
            doc => 'The format of the source file',
            valid_values => ['bed', 'gff', 'genePred', 'sample', 'pslT'],
            default_value => 'bed',
        }
    ],
};

sub execute {
    my $self = shift;

    my $cmd = 'liftOver -errorHelp';
    if($self->file_format ne 'bed') {
        $cmd .= ' -' . $self->file_format;
    }
    if($self->allow_multiple_output_regions) {
        $cmd .= ' -multiple';
    }
    
    $cmd .= join(' ', ('', $self->source_file, $self->chain_file, $self->destination_file));
    if($self->unmapped_file) {
        $cmd .= ' ' . $self->unmapped_file;
    }

    Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [$self->source_file, $self->chain_file],
        output_files => [$self->destination_file],
    );

    return 1;
}

1;
