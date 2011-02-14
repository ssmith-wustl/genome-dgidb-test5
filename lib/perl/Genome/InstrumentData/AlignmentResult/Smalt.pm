package Genome::InstrumentData::AlignmentResult::Smalt;

use strict;
use warnings;
use File::Basename;

use Genome;

class Genome::InstrumentData::AlignmentResult::Smalt {
    is => 'Genome::InstrumentData::AlignmentResult',
    has_constant => [
        aligner_name => { value => 'smalt', is_param=>1 },
    ],
    has_transient => [
        static_params => { is => 'String', is_optional => 1 }
    ]
};

sub required_arch_os { 'x86_64' }

sub required_rusage { 
    "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>90000 && mem>12000] span[hosts=1] rusage[tmp=90000, mem=12000]' -M 12000000";
}

sub _run_aligner {
    my $self = shift;

    my $input_pathnames = join ' ', @_;
    my $aligner_params = $self->aligner_params || '';
    
    # collect filepaths
    my $smalt_path = Genome::Model::Tools::Smalt->path_for_smalt_version($self->aligner_version);
    my $ref_index_base = substr($self->reference_build->full_consensus_path('fa.smi'),0,-4);
    
    unless (defined $ref_index_base && -s "$ref_index_base.smi" && -s "$ref_index_base.sma") {
      $self->error_message("Smalt index files either don't exist or are empty at $ref_index_base or " . $self->reference_build->data_directory);  
      return 0;
    };
    
    my $output_file = $self->temp_scratch_directory . "/all_sequences.sam";
    my $log_file = $self->temp_staging_directory . "/aligner.log";

    # construct the command
    $self->static_params('-f samsoft');
    my $static_params = $self->static_params;

    my $cmd = "$smalt_path map $aligner_params $static_params -o $output_file.tmp $ref_index_base $input_pathnames >>$log_file && cat $output_file.tmp >>$output_file";

    Genome::Sys->shellcmd(
        cmd          => $cmd,
        input_files  => \@_,
        output_files => [ $output_file, $log_file ],
        skip_if_output_is_present => 0,
    );

    unless (-s $output_file){
        $self->error_message('The sam output file is missing or empty.');
        return 0;
    }
    $self->status_message('Smalt alignment finished.');
    return 1;
}

sub aligner_params_for_sam_header {
    my $self = shift;
    return 'smalt map' . $self->aligner_params . ' ' . $self->static_params;
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

sub _check_read_count {return 1;}

