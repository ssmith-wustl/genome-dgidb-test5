package Genome::RunChunk::SolexaDw;

use strict;
use warnings;

use File::Basename;
use Genome;

class Genome::RunChunk::SolexaDw {
    table_name => '(select * from solexa_lane_summary@dw) solexa_dw',
    id_by => ['seq_id'],
    has => [
        _gm_obj             => { is => 'Genome::RunChunk::Solexa', id_by => 'seq_id', is_optional => 1 },
        short_name          => {
                                doc => 'The essential portion of the run name which identifies the run.  The rest is redundent information about the instrument, date, etc.',
                                is => 'String', 
                                calculate_from => ['run_name'],
                                calculate => q|($run_name =~ /_([^_]+)$/)[0]|
                            },
        full_name                       => { calculate_from => ['run_name','subset_name'], calculate => q|"$run_name/$subset_name"| },
        run_name                        => { },
        subset_name                     => { column_name => 'LANE' },
        sample_name                     => { },
        library_name                    => { },
        sample                          => { is => 'Genome::Sample', where => [ 'sample_name' => \'sample_name' ] },

        unique_reads_across_library     => { },
        duplicate_reads_across_library  => { },
        read_length                     => { }, 

        #rename not to be platform specific and move up
        clusters                        => { },
        is_paired_end                   => { 
                                             calculate_from => ['run_type'],
                                             calculate => q| if ($run_type =~ m/Paired End Read (\d)/) {
                                                                return $1;
                                                             }
                                                             else {
                                                                 return 0;
                                                             } |
                                           },
        run_type                        => { },
        gerald_directory                => { },
        median_insert_size              => { },
        sd_above_insert_size            => { },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

require Genome::RunChunk;

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
