
package Genome::Project::Contact; 
use strict;
use warnings;

class Genome::Project::Contact {
    table_name =>   "(select * from contact\@oltp) contact",
    id_properties => [
        con_id      => { is => 'Number', len => 10 },
    ],
    has => [
        email       => { is => 'Email', column_name => 'CONTACT_EMAIL' },
        name        => { is => 'Text',  column_name => 'CONTACT_NAME', },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

# Adaptor for GSC::Contact
#
# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.
#
# This module should contain only UR class definitions,
# relationships, and support methods.

