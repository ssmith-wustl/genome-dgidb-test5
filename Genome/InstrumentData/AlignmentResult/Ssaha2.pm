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
    "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>90000 && mem>10000] span[hosts=1] rusage[tmp=90000, mem=10000]' -M 10000000 -n 4";
}

sub _run_aligner {
    my $self = shift;
    my $input_pathnames = join ' ', @_;

    my $aligner_params = $self->aligner_params;
    my $ssaha_path = Genome::Model::Tools::Ssaha2->path_for_ssaha2_version($self->aligner_version);

    # get refseq info
    my $reference_build = $self->reference_build;
    my $ref_pathname = (File::Basename::fileparse($reference_build->full_consensus_path('fa')))[1];
    my $ref_index = $ref_pathname . 'all_sequences.ssaha2';
    
    my $output_file = $self->temp_scratch_directory . "/all_sequences.sam";
    my $log_file = $self->temp_staging_directory . "/aligner.log";

    # ex: ssaha2 -skip 3 -kmer 13 -best 1 -outfile ~/alignment-test/ssaha/best.sam -output sam -save ~/reference_human/all_sequences.ssaha2 ~/alignment-test/s21_seq.fq ~/alignment-test/s22_seq.fq
    my $cmd = "$ssaha_path $aligner_params -outfile $output_file.tmp -output sam -save $ref_index $input_pathnames >>$log_file && cat $output_file.tmp >>$output_file";

    Genome::Utility::FileSystem->shellcmd(
        cmd          => $cmd,
        input_files  => \@_,
        output_files => [ $output_file, $log_file ],
        skip_if_output_is_present => 0,
    );

    unless (-s $output_file){
        $self->error_message('The sam output file is missing or empty.');
        die $self->error_message;
    }
    $self->status_message('SSAHA2 alignment finished.');
    return 1;
}

sub aligner_params_for_sam_header {
    my $self = shift;

    #die 'remove this die statement and put the command line use to run the aligner here!';
    # for bwa this looks like "bwa aln -t4; bwa samse 12345'
    return 'ssaha2 ' . $self->aligner_params;
}
