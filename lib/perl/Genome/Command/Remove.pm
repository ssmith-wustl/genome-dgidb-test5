package Genome::Command::Remove;

use strict;
use warnings;

use Genome;

class Genome::Command::Remove {
    is => 'Genome::Command::Base',
    #has_input => [
    #    items => { 
    #        is => 'Genome::XXXX',
    #        shell_args_position => 1,
    #        is_many => 1,
    #        doc => 'items to remove, specified by id or expression'
    #    },
    #],
    has_optional_transient => [
        items => { is_many => 1 },
        _deletion_params => { is_many => 1 },
    ],
    doc => 'delete selected items from the system',
};

sub execute {
    my $self = shift;
    
    my @i = $self->items();
    my @deletion_params = $self->_deletion_params();

    $self->status_message("Removing " . scalar(@i) . " " . $i[0]->__label_name__ . " entries...");
    sleep 5;
    
    for my $i (@i) {
        $self->status_message("deleting " . $i->__display_name__ . "...");
        $i->delete(@deletion_params);
        print "$i\n";
    }

    $self->status_message("deletion complete.");
    return 1;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/InstrumentData/Command/Remove.pm $
#$Id: Remove.pm 53285 2009-11-20 21:28:55Z fdu $
