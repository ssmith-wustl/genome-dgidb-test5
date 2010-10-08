package EGAP::Protein;

use strict;
use warnings;

use EGAP;
use Carp 'confess';

class EGAP::Protein {
    type_name => 'protein',
    schema_name => 'files',
    data_source => 'EGAP::DataSource::Proteins',
    id_by => [
        protein_name => { is => 'Text' },
    ],
    has => [
        file_path => { is => 'Path' },
        internal_stops => { is => 'Boolean' },
        fragment => { is => 'Boolean' },
        transcript_name => { is => 'Text' },
        gene_name => { is => 'Text' },
        sequence_name => { is => 'Text' },
        sequence_string => { is => 'Text' },
    ],
    has_optional => [
        cellular_localization => { is => 'Text' },
        cog_id => { is => 'Text' },
        enzymatic_pathway_id => { is => 'Text' },
    ],
};

sub transcripts {
    my ($self, $transcripts_file) = @_;
    confess 'Not implemented!';
    return;
}
1;
