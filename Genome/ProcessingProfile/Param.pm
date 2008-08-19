package Genome::ProcessingProfile::Param;

use strict;
use warnings;

use above "Genome";

class Genome::ProcessingProfile::Param {
    type_name => 'processing profile param',
    table_name => 'PROCESSING_PROFILE_PARAM',
    id_by => [
              processing_profile => {
                                   is => 'Genome::ProcessingProfile',
                                   id_by => 'processing_profile_id',
                                   constraint_name=> 'PPP_PP_FK',
                               },
              name            => { is => 'VARCHAR2', len => 100, column_name => 'PARAM_NAME' },
              value           => { is => 'VARCHAR2', len => 1000, column_name => 'PARAM_VALUE' },
          ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
