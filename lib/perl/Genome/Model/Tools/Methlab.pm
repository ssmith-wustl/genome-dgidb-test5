package Genome::Model::Tools::Methlab;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Methlab
{
  is => 'Command',
};

sub help_brief
{
  return 'Tools to make sense of methylation array data, and then draw some pretty pictures';
}

1;
