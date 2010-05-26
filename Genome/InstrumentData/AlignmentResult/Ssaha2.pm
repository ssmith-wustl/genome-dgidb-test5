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
    has_optional => [
         _bwa_sam_cmd => { is=>'Text' }
    ]
};

sub required_arch_os { 'x86_64' }

# fill me in here with what compute resources you need.
sub required_rusage { 
    "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>90000 && mem>10000] span[hosts=1] rusage[tmp=90000, mem=10000]' -M 10000000 -n 4";
}


sub _run_aligner {
    my $self = shift;
    my @input_pathnames = @_;

    my $tmp_dir = $self->temp_scratch_directory;

    # get refseq info
    my $reference_build = $self->reference_build;
    my $ref_basename = File::Basename::fileparse($reference_build->full_consensus_path('fa'));
    my $reference_fasta_path = sprintf("%s/%s", $reference_build->data_directory, $ref_basename);

    my $aligner_params = $self->aligner_params;

    my $path_to_ssaha = Genome::Model::Tools::Ssaha2->path_for_ssaha2_version($self->aligner_version);


    # run your aligner here

    # put your output file here, append to this file!

    my $output_file = $self->temp_staging_directory . "/all_sequences.sam"

    return 1;
}

sub aligner_params_for_sam_header {
    my $self = shift;

    die 'remove this die statement and put the command line use to run the aligner here!';    

    # for bwa this looks like "bwa aln -t4; bwa samse 12345'
}
