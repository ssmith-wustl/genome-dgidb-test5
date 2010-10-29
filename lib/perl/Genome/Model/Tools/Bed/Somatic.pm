package Genome::Model::Tools::Bed::Somatic;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Bed::Somatic {
    is => ['Command'],
    has_input => [
        tumor_bed_file => {
            is => 'Text',
            doc => 'The BED format file of intervals to pull out bases from reference.',
        },
        normal_bed_file => {
            is => 'Text',
            doc => 'The BED format file of intervals to pull out bases from reference.',
        },
        somatic_file => {
            is => 'Text',
            doc => 'The stupid result',
        }
          ],
};


sub execute {
    my $self = shift;

    my $tier1_cmd = "/gsc/pkg/bio/bedtools/installed-64/intersectBed -wa -v -a " . $self->tumor_bed_file . " -b " . $self->normal_bed_file . " > " . $self->somatic_file;  

  
       return 1;
}
