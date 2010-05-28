package Genome::InstrumentData::AlignmentResult::Ssaha2;

use strict;
use warnings;
use File::Basename;

use Genome;

class Genome::InstrumentData::AlignmentResult::Ssaha2 {
    is => 'Genome::InstrumentData::AlignmentResult',
    has_constant => [
        aligner_name => { value => 'ssaha2', is_param=>1 },
    ]
};

sub required_arch_os { 'x86_64' }

# fill me in here with what compute resources you need.
sub required_rusage { 
    "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>90000 && mem>10000] rusage[tmp=90000, mem=10000]' -M 10000000";
}

sub _run_aligner {
    my $self = shift;

    # a little input validation
    my $input_pathnames = join ' ', @_;
    my $aligner_params = $self->aligner_params;
    if ( @_ > 1 && not $aligner_params =~ /-pair/ ){
        $self->error_message('Multiple FastQs given, but -pair option not set.');
        return 0;
    }
    
    # collect filepaths
    my $ssaha_path = Genome::Model::Tools::Ssaha2->path_for_ssaha2_version($self->aligner_version);
    my $ref_index = $self->reference_build->data_directory . '/all_sequences.ssaha2';
    my $output_file = $self->temp_scratch_directory . "/all_sequences.sam";
    my $log_file = $self->temp_staging_directory . "/aligner.log";

    # construct the command (using hacky temp-file to append)
    my $cmd = "$ssaha_path $aligner_params -best 1 -udiff 1 -align 0 -output sam_soft -outfile $output_file.tmp -save $ref_index $input_pathnames >>$log_file && cat $output_file.tmp >>$output_file";

    $DB::single = 1; # STOP, collaborate && listen
    Genome::Utility::FileSystem->shellcmd(
        cmd          => $cmd,
        input_files  => \@_,
        output_files => [ $output_file, $log_file ],
        skip_if_output_is_present => 0,
    );

    $DB::single = 1; # STOP, collaborate && listen

    unless (-s $output_file){
        $self->error_message('The sam output file is missing or empty.');
        return 0;
    }
    $self->status_message('SSAHA2 alignment finished.');
    return 1;
}

sub aligner_params_for_sam_header {
    my $self = shift;
    return 'ssaha2 ' . $self->aligner_params;
}
