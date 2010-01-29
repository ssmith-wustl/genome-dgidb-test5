package Genome::InstrumentData::Imported;

#REVIEW fdu 11/17/2009
#More methods could be implemented for calculating metrics and
#resolving file path with Imported-based models soon in use

use strict;
use warnings;

use Genome;
use File::stat;

class Genome::InstrumentData::Imported {
    is => ['Genome::InstrumentData'],
    table_name => 'IMPORTED_INSTRUMENT_DATA',
    id_by => ['id'],
    has => [
        import_date         => { is => 'DATE',     len => 19 },
        user_name           => { is => 'VARCHAR2', len => 256},
        sample_id           => { is => 'NUMBER',   len => 20 },
        original_data_path  => { is => 'VARCHAR2', len => 256},
        sample_name         => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        import_source_name  => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        import_format       => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        sequencing_platform => { is => 'VARCHAR2', len => 64, is_optional => 1 },
        description         => { is => 'VARCHAR2', len => 512,is_optional => 1 },
        read_count          => { is => 'NUMBER',   len => 20, is_optional => 1 },
        base_count          => { is => 'NUMBER',   len => 20, is_optional => 1 },
        data_directory      => { via => 'disk_allocation', to => 'absolute_path' },
        disk_allocation     => { is => 'Genome::Disk::Allocation', reverse_as => 'owner', is_many => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub calculate_alignment_estimated_kb_usage {
    my $self = shift;
    if (-s $self->original_data_path) {
        my $stat = stat($self->original_data_path);
        return int($stat->size/1000 + 100);   #use kb as unit
    } 
    else {
        return 250000000;
    }
}


sub create {
    my $class = shift;
    
    my %params = @_;
    my $user   = getpwuid($<); 
    my $date   = UR::Time->now;

    $params{import_date} = $date;
    $params{user_name}   = $user; 

    my $self = $class->SUPER::create(%params);

    return $self;
}


1;

