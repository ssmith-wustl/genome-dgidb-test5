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
        run_type                        => { },
        gerald_directory                => { },
        median_insert_size              => { },
        sd_above_insert_size            => { },
        flow_cell_id                    => { }, # = short name
        lane                            => { }, # = subset_name
        is_external                     => { },
        clusters                        => { column_name => 'FILT_CLUSTERS' },
        short_name => {
            doc => 'The essential portion of the run name which identifies the run.  The rest is redundent information about the instrument, date, etc.',
            is => 'Text', 
            calculate_from => ['run_name'],
            calculate => q|($run_name =~ /_([^_]+)$/)[0]|
        },
        is_paired_end                   => {
                                            calculate_from => ['run_type'],
                                            calculate => q| if (defined($run_type) and $run_type =~ m/Paired End Read (\d)/) {
                                                                return $1;
                                                             }
                                                             else {
                                                                 return 0;
                                                             } |
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

sub calculate_alignment_estimated_kb_usage {
    my $self = shift;
    # These default values should be replaced with an equation that takes into account:
    # 1.) read_length
    # 2.) reference sequence size
    # 3.) clusters
    # 4.) paired end
    if ($self->is_paired_end) {
        return 2000000;
    } else {
        return 1000000;
    }
}

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

sub fastq_filenames {
    my $self = shift;
    my $seq_dedup = shift;
    my @fastqs;
    if ($self->is_external) {
        @fastqs = $self->resolve_external_fastq_filenames;
    } else {
        @fastqs = $self->resolve_fastq_filenames;
    }
    return @fastqs;
}

sub desc {
    my $self = shift;
    return $self->full_name .'('. $self->id .')';
}

sub resolve_fastq_filenames {
    my $self = shift;
    my $seq_dedup = shift;

    my $lane = $self->subset_name;

    ###################
    #
    #srf 2 fastq goes here
    #if ->srf_path filename is not null and exists, run srf2fastq.
    #figure out how it will spit out paired data.
    #dump this crap into temp on the blade, PROBABLY don't run sol2sanger...
    #still run fastq2bfq, rest of pipeline continues unaltered.
    #####################



    my $gerald_directory = $self->gerald_directory;
    unless ($gerald_directory) {
        die('No gerald directory in the database for or '. $self->desc);
    }
    unless (-d $gerald_directory) {
        die('No gerald directory on the filesystem for '. $self->desc .' : '. $gerald_directory);
    }

    # handle fragment or paired-end data
    my @solexa_output_paths;
    if ($self->is_paired_end) {
        if (-e "$gerald_directory/s_${lane}_1_sequence.txt") {
            push @solexa_output_paths, "$gerald_directory/s_${lane}_1_sequence.txt";
        }
        elsif (-e "$gerald_directory/Temp/s_${lane}_1_sequence.txt") {
            push @solexa_output_paths, "$gerald_directory/Temp/s_${lane}_1_sequence.txt";
        }
        else {
            die "No gerald forward data in directory for lane $lane! $gerald_directory";
        }

        if (-e "$gerald_directory/s_${lane}_2_sequence.txt") {
            push @solexa_output_paths, "$gerald_directory/s_${lane}_2_sequence.txt";
        }
        elsif (-e "$gerald_directory/Temp/s_${lane}_2_sequence.txt") {
            push @solexa_output_paths, "$gerald_directory/Temp/s_${lane}_2_sequence.txt";
        }
        else {
            die "No gerald reverse data in directory for lane $lane! $gerald_directory";
        }
    }
    else {
        if (-e "$gerald_directory/s_${lane}_sequence.txt") {
            push @solexa_output_paths, "$gerald_directory/s_${lane}_sequence.txt";
        }
        elsif (-e "$gerald_directory/Temp/s_${lane}_sequence.txt") {
            push @solexa_output_paths, "$gerald_directory/Temp/s_${lane}_sequence.txt";
        }
        else {
            die "No gerald data in directory for lane $lane! $gerald_directory";
        }
    }

    return @solexa_output_paths;
}

sub resolve_external_fastq_filenames {
    my $self = shift;
    my $seq_dedup = shift;

    my @fastq_pathnames;
    my $fastq_pathname = $self->create_temp_file_path('fastq');
    unless ($fastq_pathname) {
        die "Failed to create temp file for fastq!";
    }
    return ($fastq_pathname);
}

sub _calculate_total_read_count {
    my $self = shift;

    if($self->is_external) {
        my $data_path_object = Genome::MiscAttribute->get(entity_id => $self->id, property_name=>'full_path');
        my $data_path = $data_path_object->value;
        my $lines = `wc -l $data_path`;
        return $lines/4;
    }
    if ($self->clusters <= 0) {
        die('Impossible value '. $self->clusters .' for clusters field for solexa lane '. $self->id);
    }

    return $self->clusters;
}

1;

#$HeaderURL$
#$Id$
