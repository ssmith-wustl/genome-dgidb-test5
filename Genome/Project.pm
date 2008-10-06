
package Genome::Project; 

# Adaptor for GSC::Setup::Project
#
# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.
#
# This module should contain only UR class definitions,
# relationships, and support methods.

use strict;
use warnings;
use Genome;

class Genome::Project {
    id_properties => ['setup_project_id'],
    table_name =>   "(select * from setup_project\@oltp p join setup\@oltp s on setup_id = setup_project_id where project_type != 'finishing') project ",
    has => [
        #_oltp_project       => { is => 'GSC::Setup::Project', id_by => 'setup_project_id' },
        
        # get these directly, since we can't join through any app objects
        name                => { is => 'Text', len => 64, column_name => 'SETUP_NAME' },
        status              => { is => 'Text', column_name => 'SETUP_STATUS' },
        description         => { is => 'Text', len => 256, column_name => 'SETUP_DESCRIPTION' },
        project_type        => { is => 'Text', len => 32 },
        mailing_list        => { is => 'Text', column_name => 'MAILING_LIST' }, 
 
        external_contact        => { is => 'Genome::Project::Contact', id_by => 'ext_con_id' },
        external_contact_name   => { is => 'Text', via => 'external_contact', to => 'name' }, 
        external_contact_email  => { is => 'Text', via => 'external_contact', to => 'email' }, 

        internal_contact        => { is => 'Genome::Project::Contact', id_by => 'internal_con_id' },
        internal_contact_name   => { is => 'Text', via => 'internal_contact', to => 'name' }, 
        internal_contact_email  => { is => 'Text', via => 'internal_contact', to => 'email' }, 

        # not used, but available
        acct_id             => { is => 'Number', len => 10 },
        het_testing         => { is => 'Boolean' },
        is_submitted        => { is => 'Boolean' },
        parent_project_id   => { is => 'Number', len => 10 },
        setup_project_id    => { is => 'Number', len => 10 },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

