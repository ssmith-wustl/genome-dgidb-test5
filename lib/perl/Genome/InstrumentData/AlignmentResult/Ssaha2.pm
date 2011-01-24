package Genome::InstrumentData::AlignmentResult::Ssaha2;

use strict;
use warnings;
use File::Basename;

use Genome;

class Genome::InstrumentData::AlignmentResult::Ssaha2 {
    is => 'Genome::InstrumentData::AlignmentResult',
    has_constant => [
        aligner_name => { value => 'ssaha2', is_param=>1 },
    ],
    has_transient => [
        static_params => { is => 'String', is_optional => 1 }
    ]
};

sub required_arch_os { 'x86_64' }

sub required_rusage { 
    "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>90000 && mem>24000] rusage[tmp=90000, mem=24000]' -M 24000000";
}

sub _run_aligner {
    my $self = shift;

    my $input_pathnames = join ' ', @_;
    my $aligner_params = $self->aligner_params;
    
    # collect filepaths
    my $ssaha_path = Genome::Model::Tools::Ssaha2->path_for_ssaha2_version($self->aligner_version);
    my $ref_index = $self->reference_build->full_consensus_path('ssaha2.body');
    $ref_index =~ s/\.body$//;;  # all we want to pass is all_sequences.ssaha2
    
    unless (defined $ref_index && -s $ref_index) {
      $self->error_message("Ssaha2 index file either doesn't exist or is empty at $ref_index or " . $self->reference_build->data_directory);  
      die;
    };
    
    my $output_file = $self->temp_scratch_directory . "/all_sequences.sam";
    my $log_file = $self->temp_staging_directory . "/aligner.log";

    # construct the command (using hacky temp-file to append)
    $self->static_params('-best 1 -udiff 1 -align 0 -output sam_soft');
    $aligner_params = $aligner_params || '';
    if ( @_ > 1 && not $aligner_params =~ /-pair/ ){
        my ($lower,$upper) = $self->_derive_insert_size_bounds;
        $self->static_params($self->static_params . " -pair $lower,$upper");
    }
    my $static_params = $self->static_params;

    my $cmd = "$ssaha_path $aligner_params $static_params -outfile $output_file.tmp -save $ref_index $input_pathnames >>$log_file && cat $output_file.tmp >>$output_file";

    Genome::Sys->shellcmd(
        cmd          => $cmd,
        input_files  => \@_,
        output_files => [ $output_file, $log_file ],
        skip_if_output_is_present => 0,
    );

    # 
    # Ssaha doesn't output unaligned reads by default. There may be a way to do so, or it might take comparing input / output.
    #
    unless (-s $output_file){
        $self->error_message('The sam output file is missing or empty.');
        return 0;
    }
    $self->status_message('SSAHA2 alignment finished.');
    return 1;
}

sub aligner_params_for_sam_header {
    my $self = shift;
    return 'ssaha2 ' . $self->aligner_params . ' ' . $self->static_params;
}

# note: this may be completely wrong. fix later!
sub _derive_insert_size_bounds {
    my $self = shift;

    my $median = $self->instrument_data->median_insert_size;
    my $stddev = $self->instrument_data->sd_above_insert_size;
    #my $readlen = $self->instrument_data->read_length;
    my ( $upper, $lower );
    
    if ( defined $median && defined $stddev ) {
        $upper = $median + $stddev*5;
        $lower = $median - $stddev*5;
    }
    
    if ( !defined $upper || $upper <= 0 ) {
        $self->status_message("Calculated upper bound on insert size is undef or less than 0, defaulting to 600");
        $upper = 600;
    }
    if ( !defined $lower || not $median || $lower < 0 || $lower > $upper ) {
        # alternative default = read_length + rev_read_length
        $self->status_message("Calculated lower bound on insert size is undef or invalid, defaulting to 100");
        $lower = 100;
    }
    return ($lower,$upper);
}

sub fillmd_for_sam { return 1; } 

sub _check_read_count {
    my $self = shift;
    $self->warning_message("SSAHA2 does not support outputting unaligned reads.  Cannot verify read count against original fasta.");
    return 1;
}

