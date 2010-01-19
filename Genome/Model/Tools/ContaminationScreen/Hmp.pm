package Genome::Model::Tools::ContaminationScreen::Hmp;

use strict;
use warnings;

use Genome;    

class Genome::Model::Tools::ContaminationScreen::Hmp {
    is => 'Command',
    is_abstract => 1,
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;
}

sub execute
{
    die("implement execute in inheriting class");
}

1;
