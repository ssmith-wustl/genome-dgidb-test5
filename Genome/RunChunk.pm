package Genome::RunChunk;

use strict;
use warnings;

use Genome;
use File::Basename;

use GSC;
use GSCApp;

# This should not be necessary before working with objects which use App.
#App->init; 

class Genome::RunChunk {
    type_name => 'run chunk',
    table_name => 'GENOME_MODEL_RUN',
    id_by => [
        genome_model_run_id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        sequencing_platform => { is => 'VARCHAR2', len => 255 },    
        run_name            => { is => 'VARCHAR2', len => 500, is_optional => 1 },
        subset_name         => { is => 'VARCHAR2', len => 32, is_optional => 1, column_name => "LIMIT_REGIONS" },
        sample_name         => { is => 'VARCHAR2', len => 255 },
        events              => { is => 'Genome::Model::Event', is_many => 1, reverse_id_by => "run" },
        seq_id              => { is => 'NUMBER', len => 15, is_optional => 1 },
        
        # move both of these into a solexa subclass
        _run_lane_solexa    => { 
                                doc => 'Lane representation from LIMS.  This class should eventually be a base class for data like this.',
                                is => 'GSC::RunLaneSolexa',
                                calculate => q|
                                    GSC::RunLaneSolexa->get($seq_id);
                                |,
                                calculate_from => ['seq_id']
                            },
        short_name          => { 
                                doc => 'The essential portion of the run name which identifies the run.  The rest is redundent information about the instrument, date, etc.',
                                is => 'String', 
                                calculate_from => ['run_name'], 
                                calculate => q|($run_name =~ /_([^_]+)$/)[0]| 
                            },
        library_name                    => { via => "_run_lane_solexa" },
        unique_reads_across_library     => { via => "_run_lane_solexa" },
        duplicate_reads_across_library  => { via => "_run_lane_solexa" },
        
        # deprecated
        limit_regions       => { is => 'VARCHAR2', len => 32, is_optional => 1, column_name => "LIMIT_REGIONS" },
        full_path           => { is => 'VARCHAR2', len => 767, column_name => "FULL_PATH" },
        
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub name {
    my $self = shift;

    my $path = $self->full_path;

    my($name) = ($path =~ m/.*\/(.*EAS.*?)\/?$/);
    if (!$name) {
	   $name = "run_" . $self->id;
    }
    return $name;
}

1;
