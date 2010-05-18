#REVIEW fdu 11/17/2009
#Need documentation

package Genome::Measurable; 

use strict;
use warnings;

class Genome::Measurable {
    table_name => 'GSC.PHENOTYPE_MEASURABLE',
    id_by => [
        subject_id                  => { is => 'Number',
                                        doc => 'the numeric ID for the specimen in both the LIMS and the analysis system', 
                                    },
    ],
    has => [
        subject_type                => { is => 'Text', 
                                         calculate => q|
                                            if ($self->isa("Genome::Sample")) {
                                                return "organism sample"
                                            }
                                            elsif ($self->isa("Genome::Taxon")) {
                                                return "organism taxon"
                                            }
                                            else {
                                                Carp::confess("No subject type specified for " . ref($self) . "!");
                                            }
                                         | 
                                       },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

