# Review gsanders jlolofie
# The main think of here is adding some progrommatic way to pass every processing profile attribute to the workflow.
# Currently when a param is added to the workflow, I need to go add that as a class property to the processing profile,
# and then add it to this module to pass it to the workflow.
# Also should we check the workflow->execute return code at the end? I think we should. Lets talk to eclark about this.

package Genome::Model::Event::Build::GenotypeMicroarray::NoOp;

use strict;
use warnings;
use Genome;

class Genome::Model::Event::Build::GenotypeMicroarray::NoOp {
    is => ['Genome::Model::Event'],
};


sub execute {
    my $self = shift;
    $DB::single=1;
    return 1;

}

1;
