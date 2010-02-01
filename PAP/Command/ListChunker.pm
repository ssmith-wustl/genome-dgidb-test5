#$Id$

package PAP::Command::ListChunker;

use strict;
use warnings;

use Workflow;

use List::MoreUtils qw/part/;
use English;
use Carp;


class PAP::Command::ListChunker {
    is  => ['PAP::Command'],
    has => [
        list  => { is => 'ARRAY', doc => 'list to split up'                             },
        chunk_number  => { is => 'SCALAR', doc => 'number of sequences per output file'         },
        list_of_lists  => { is => 'ARRAY', doc => 'list of lists/array of arrays that are split out'         },
    ],
};

operation PAP::Command::ListChunker {
    input        => [ 'list', 'chunk_number' ],
    output       => [ 'list_of_lists'],
    lsf_queue    => 'short',
    lsf_resource => 'rusage[tmp=100]',
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "chunk/split a list";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This is for splitting up a list into a collection of smaller lists.
EOS
}

sub execute {

    my $self = shift;


    my @list   = $self->list();
    unless(@list) {
        croak "list is empty!";
    }
    my $chunk_number   = $self->chunk_number();
    unless($chunk_number > 0) {
        croak "chunk number is bad: $chunk_number";
    }
    my @lol =  ( );

    @lol = part { int(rand($chunk_number)); } @list;
    $self->list_of_lists(\@lol);

    return 1;

}
 
1;
