package Genome::InstrumentData::Solexa;

use strict;
use warnings;

use Genome;

use File::Basename;

class Genome::InstrumentData::Solexa {
    is => 'Genome::InstrumentData',
    table_name => <<EOS
        (
            select to_char(seq_id) id, 
                seq_id genome_model_run_id, 
                lane limit_regions,
                s.* 
            from solexa_lane_summary\@dw s
        ) 
        solexa_detail
EOS
    ,
    has_optional => [
        # TODO: fill these, even though this is a non-creatable class
        unique_reads_across_library     => { },
        duplicate_reads_across_library  => { },
        read_length                     => { }, 
        clusters                        => { },
        run_type                        => { },
        gerald_directory                => { },
        median_insert_size              => { },
        sd_above_insert_size            => { },
        is_external                     => { },
        flow_cell_id                    => { }, # = short name
        lane                            => { }, # = subset_name
        
        short_name => {
            doc => 'The essential portion of the run name which identifies the run.  The rest is redundent information about the instrument, date, etc.',
            is => 'Text', 
            calculate_from => ['run_name'],
            calculate => q|($run_name =~ /_([^_]+)$/)[0]|
        },
        
        is_paired_end                   => { 
                                             calculate_from => ['run_type'],
                                             calculate => q| if ($run_type eq 'Paired End Read 2') {
                                                                return 2;
                                                             }
                                                             else {
                                                                return 0;
                                                             } |,
                                             #calc_sql => "(case when run_type = 'Paired End Read 2' then 2 else 0 end) is_paired_end",
                                           },
        
        _run_lane_solexa => {
            doc => 'Solexa Lane Summary from LIMS.',
            is => 'GSC::RunLaneSolexa',
            calculate => q| GSC::RunLaneSolexa->get($id); |,
            calculate_from => ['id']
        },
         
        # deprecated, compatible with Genome::RunChunk::Solexa
        genome_model_run_id => {},
        limit_regions       => {},
        
    ],
};

sub resolve_full_path {
    my $self = shift;

    my @fs_path = GSC::SeqFPath->get(
        seq_id => $self->genome_model_run_id,
        data_type => [qw/ duplicate fastq path unique fastq path /],
    )
        or return; # no longer required, we make this ourselves at alignment time as needed

    my %dirs = map { File::Basename::dirname($_->path) => 1 } @fs_path;

    if ( keys %dirs > 1) {
        $self->error_message(
            sprintf(
                'Multiple directories for run %s %s (%s) not supported!',
                $self->run_name,
                $self->lane,
                $self->genome_model_run_id,
            )
        );
        return;
    }
    elsif ( keys %dirs == 0 ) {
        $self->error_message(
            sprintf(
                'No directories for run %s %s (%s)',
                $self->run_name,
                $self->lane,
                $self->id,
            )
        );
        return;
    }

    my ($full_path) = keys %dirs;
    $full_path .= '/' unless $full_path =~ m|\/$|;

    return $full_path;
}

#< Dump to File System >#
sub dump_to_file_system {
    #$self->warning_message("Method 'dump_data_to_file_system' not implemented");
    return 1;
}

1;

#$HeaderURL$
#$Id$
