package Genome::Sample::Command::AddFiles;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';

class Genome::Sample::Command::AddFiles { 
    is => 'Command',
    has => [
        sample => {
            is => 'Genome::Sample',
            shell_args_position => 1,
            doc => 'Sample id or name.',
        },
        files => {
            is => 'Text',
            is_many => 1,
            doc => 'Files to be stored in the sample\'s disk allocation.',
        },
    ],
};

sub help_brief {
    return 'add files to a sample';
}

sub execute {
    my $self = shift;

    my $sample = $self->sample;
    if ( not $sample ) {
        $self->error_message('No sample to add files');
        return;
    }

    $self->status_message('Add files to '.$sample->name);

    for my $file ( $self->files ) {
        my $add_file = eval{ $self->_sample->add_file($file) };
        if ( not $add_file ) {
            $self->_bail('Failed to add file: '.$file);
            return if not $add_file;
        }
    }

    $self->status_message('Add files...OK');

    return 1;
}

1;

