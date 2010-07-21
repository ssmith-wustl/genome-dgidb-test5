package Genome::ProcessingProfile::RnaSeq::454;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::RnaSeq::454 {
    is => 'Genome::ProcessingProfile::RnaSeq',
};

sub stages {
    die 'No stages implemented for 454 RNA-seq pipeline';
}


1;
