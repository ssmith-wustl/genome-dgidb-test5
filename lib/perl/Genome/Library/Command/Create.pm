package Genome::Library::Command::Create;

use strict;
use warnings;

use Genome;

class Genome::Library::Command::Create {
    is => 'Command',
    has => [
        name => { is => 'Text', doc => 'Name' },
        sample_id => { is => 'Number', doc => 'Sample id', },
    ],
};

sub sub_command_sort_position { 1 }

sub execute {
    my $self = shift;

    my $library = Genome::Library->create(
        name => $self->name,
        sample_id => $self->sample_id,
    );

    if ( not $library ) {
        $self->error_message('Cannot create library: '.Data::Dumper::Dumper($self));
        return;
    }   

    $self->status_message("Create library: ".$library->id);

    return 1;
}

1;

