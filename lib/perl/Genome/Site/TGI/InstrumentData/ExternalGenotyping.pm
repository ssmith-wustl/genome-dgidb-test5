package Genome::Site::TGI::InstrumentData::ExternalGenotyping; 

use strict;
use warnings;

use Genome;

class Genome::Site::TGI::InstrumentData::ExternalGenotyping { # EX: 2877138689
    table_name => <<SQL
    (
        select g.seq_id id, g.status status, g.organism_sample_id sample_id,
         s.full_name sample_name,
	     p.name platform_name, p.chip_type chip_name, p.version version
	    from external_genotyping\@dw g
        join genotyping_platform\@dw p on p.genotyping_platform_id = g.genotyping_platform_id
        join organism_sample\@dw s on s.organism_sample_id = g.organism_sample_id
    ) external_genotyping
SQL
    ,
    id_by => [
        id => { is => 'Text', },
    ],
    has => [
        status => { is => 'Text', },
        sample_id => { is => 'Text', },
        sample_name => { is => 'Text', },
        platform_name => { is => 'Text', },
        chip_name => { is => 'Text', },
        version => { is => 'Text', },
        import_source_name => { is_constant => 1, calculate => q| return 'external'; |, },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

1;

