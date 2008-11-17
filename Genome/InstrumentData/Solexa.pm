package Genome::InstrumentData::Solexa;

use strict;
use warnings;

use Genome;

use File::Basename;

class Genome::InstrumentData::Solexa {
    is => 'Genome::InstrumentData',
    has => [
    short_name => {
        doc => 'The essential portion of the run name which identifies the run.  The rest is redundent information about the instrument, date, etc.',
        is => 'String', 
        calculate_from => ['run_name'],
        calculate => q|($run_name =~ /_([^_]+)$/)[0]|
    },
    #< Run Lane Solexa from DW Attrs >#
    _run_lane_solexa => {
        doc => 'Solexa Lane from LIMS',
        is => 'GSC::RunLaneSolexa',
        calculate => q| GSC::RunLaneSolexa->get($id); |,
        calculate_from => [qw/ id /]
    },
    library_name                    => { via => "_run_lane_solexa" },
    unique_reads_across_library     => { via => "_run_lane_solexa" },
    duplicate_reads_across_library  => { via => "_run_lane_solexa" },
    read_length                     => { via => "_run_lane_solexa" }, 
    clusters                        => { via => "_run_lane_solexa" },
    is_paired_end                   => { 
        calculate_from => ['run_type'],
        calculate => q| if (defined($run_type) and $run_type =~ m/Paired End Read (\d)/) {
        return $1;
        }
        else {
        return 0;
        } |
    },
    run_type                        => { via => "_run_lane_solexa" },
    gerald_directory                => { via => "_run_lane_solexa" },
    median_insert_size              => { via => "_run_lane_solexa" },
    sd_above_insert_size            => { via => "_run_lane_solexa" },
    limit_regions                   => { via => "_run_lane_solexa", to => 'lane' }, # legacy RunChunk
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
