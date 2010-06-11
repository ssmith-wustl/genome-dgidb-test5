package Genome::Model::Event::Build::ProcessingProfileMethodWrapper;

use strict;
use warnings;

use Genome;

# this command is not intended to be executed by users

class Genome::Model::Event::Build::ProcessingProfileMethodWrapper {
    is  => 'Command',
    has_input => [
        build_id => {
            is  => 'Number',
            doc => 'Get build by id'
        },
    ]
};

# the only purpose of this command is to call _execute_build on the processing_profile

sub execute {
    my $self = shift;

    $DB::single=1;

    my $build = Genome::Model::Build->get($self->build_id) 
      or die 'cannot load build object for ' . $self->build_id;

    my $pp = $build->processing_profile;

    my $rv = $pp->_execute_build($build);
    die '_execute_build returned undef' if !defined $rv;

    return $rv;
}

1;

#$HeadURL$
#$Id$
