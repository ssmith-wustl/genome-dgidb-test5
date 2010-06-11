package Genome::InstrumentData::AlignmentResult::Novocraft;

use strict;
use warnings;
use File::Basename;

use Genome;

class Genome::InstrumentData::AlignmentResult::Novocraft {
    is => 'Genome::InstrumentData::AlignmentResult',
    has_constant => [
        aligner_name => { value => 'Novocraft', is_param=>1 },
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

    # get refseq info
    my $reference_build = $self->reference_build;
    my $reference_novocraft_index_path = $reference_build->full_consensus_path('novocraft');

    my $aligner_params = $self->aligner_params;

    my $path_to_novoalign = Genome::Model::Tools::Novocraft->path_for_novocraft_version($self->aligner_version);

    my $output_file = $self->temp_scratch_directory . "/all_sequences.sam";
    my $log_file = $self->temp_staging_directory . "/aligner.log";

    my $temp_aligned_sequences_file = $self->temp_scratch_directory . "/temp_aligned_sequences.sam";
    my $temp_unaligned_fq_file = $self->temp_scratch_directory . "/temp_unaligned_sequences.fq";
	my $temp_unaligned_sam_file = $self->temp_scratch_directory . "/temp_unaligned_sequences.sam";

    if ( @input_pathnames > 2 ) {
        $self->error_message("Input pathnames shouldn't have more than 2...: " . Data::Dumper::Dumper(\@input_pathnames) );
        die $self->error_message;
    }
    
    # TODO: Append unaligned reads, make sure error and regular logging work. General testing.
    $DB::single = 1;
    my $cmdline = sprintf('%s -d %s -f %s -o SAM 1>> %s',
        $path_to_novoalign,
        $reference_novocraft_index_path,
        join(' ', @input_pathnames),
        $output_file
    );
    
    Genome::Utility::FileSystem->shellcmd(
        cmd                         => $cmdline,
        input_files                 => [@input_pathnames],
        output_files                => [$output_file],
        skip_if_output_is_present   => 0,
    );
        
    return 1;
}

sub aligner_params_for_sam_header {
    my $self = shift;

    my $aligner_params = $self->aligner_params || '';
    return "novocraft " . $aligner_params;
    # for bwa this looks like "bwa aln -t4; bwa samse 12345'
}
