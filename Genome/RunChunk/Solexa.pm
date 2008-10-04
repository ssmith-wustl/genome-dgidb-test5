package Genome::RunChunk::Solexa;

use strict;
use warnings;

use Genome;
use Genome::RunChunk;
use File::Basename;

class Genome::RunChunk::Solexa {
    is => [
           'Genome::RunChunk',
    ],
    has => [
        _dw_obj             => { is => 'Genome::RunChunk::SolexaDw', id_by => 'id' },
        _run_lane_solexa    => {
                                doc => 'Lane representation from LIMS.  This class should eventually be a base class for data like this.',
                                is => 'GSC::RunLaneSolexa',
                                calculate => q| GSC::RunLaneSolexa->get($seq_id); |,
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
        read_length                     => { via => "_run_lane_solexa" }, 

        #rename not to be platform specific and move up
        clusters                        => { via => "_run_lane_solexa" },
        is_paired_end                   => { 
                                             calculate_from => ['run_type'],
                                             calculate => q| if ($run_type =~ m/Paired End Read (\d)/) {
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
    ],
};

sub resolve_sequencing_platform {
    return 'solexa';
}

sub resolve_subset_name {
    my $class = shift;
    my $read_set = shift;
    unless ($read_set) {
        $class->error_message('No read set specified in resolve_subset_name');
        return;
    }
    return $read_set->lane;
}

sub resolve_full_path {
    my $class = shift;
    my $read_set = shift;

    my $seq_fs_data_types = ["duplicate fastq path" , "unique fastq path"];
    my @fs_path = GSC::SeqFPath->get(seq_id => $read_set->id, data_type => $seq_fs_data_types);
    my $full_path;
    if (not @fs_path) {
        # no longer required, we make this ourselves at alignment time as needed
        $class->status_message('Failed to find the path for data set'. $class->_desc_dw_obj($read_set) .'!');
        return;
    } else {
        my %dirs = map { File::Basename::dirname($_->path) => 1 } @fs_path;
        if (keys(%dirs)>1) {
            $class->error_message('Multiple directories for run '. $class->_desc_dw_obj($read_set) .' not supported!');
            return;
        }
        elsif (keys(%dirs)==0) {
            $class->error_message('No directories for run '. $class->_desc_dw_obj($read_set) .'??');
            return;
        }
        ($full_path) = keys %dirs;
        $full_path .= '/' unless $full_path =~ m|\/$|;
    }
    return $full_path;
}

sub _dw_class { 'GSC::RunLaneSolexa' }

sub _desc_dw_obj {
    my $class = shift;
    my $obj = shift;
    return $obj->run_name . "/" . $obj->lane . " (" . $obj->id . ")";
}


1;
