package Genome::Model::Event::Build::ProcessingProfileMethodWrapper;

use strict;
use warnings;
use Genome;

# this command is not intended to be executed by users
# the only purpose of this command is to call _execute_build, or some other method, on the processing_profile

class Genome::Model::Event::Build::ProcessingProfileMethodWrapper {
    is  => 'Command',
    has_input => [
        build_id => {
            is  => 'Number',
            doc => 'specify the build by id'
        },
        method_name => {
            is => 'Text',
            is_optional => 1,
            default_value => '_execute_build',
            doc => 'the method on the processing profile to call, passing a build (defaults to _execute_build())',
        }
    ]
};

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64] rusage[tmp=90000:mem=16000]' -M 16000000";
}

sub execute {
    my $self = shift;


    my $build = Genome::Model::Build->get($self->build_id) 
      or die 'cannot load build object for ' . $self->build_id;

    my $method_name = $self->method_name;

    my $pp = $build->processing_profile;

    my $rv = $pp->$method_name($build);
    die $method_name . ' returned undef' if !defined $rv;
    die $method_name . ' returned false' if !$rv;

    return $rv;
}

1;

