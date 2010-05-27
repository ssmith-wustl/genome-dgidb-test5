package Genome::InstrumentData::AlignmentResult::Bowtie;

use strict;
use warnings;
use File::Basename;

use Genome;

class Genome::InstrumentData::AlignmentResult::Bowtie {
    is => 'Genome::InstrumentData::AlignmentResult',
    has_constant => [
        aligner_name => { value => 'Bowtie', is_param=>1 },
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
    my $ref_basename = File::Basename::fileparse($reference_build->full_consensus_path('bowtie'));
    my $reference_bowtie_index_path = sprintf("%s/%s", $reference_build->data_directory, $ref_basename);

    my $aligner_params = $self->aligner_params;

    my $path_to_bowtie = Genome::Model::Tools::Bowtie->path_for_bowtie_version($self->aligner_version);

    my $output_file = $self->temp_scratch_directory . "/all_sequences.sam";
    my $log_file = $self->temp_staging_directory . "/aligner.log";

    if ( @input_pathnames == 1 ) {

        my $cmdline = "$path_to_bowtie $aligner_params $reference_bowtie_index_path $input_pathnames[0] --sam $output_file >>$log_file";

        $self->status_message( "Attempting to run with 1 arg: " . $cmdline . "\n");
        Genome::Utility::FileSystem->shellcmd(
            cmd                         => $cmdline,
            input_files                 => [$reference_bowtie_index_path, $input_pathnames[0]],
            output_files                => [$output_file],
            skip_if_output_is_present   => 0,
        );

    }
    elsif ( @input_pathnames == 2 ) {
	
        my $cmdline = "$path_to_bowtie $aligner_params $reference_bowtie_index_path -1 $input_pathnames[0] -2 $input_pathnames[1] --sam $output_file >>$log_file";
    
        
        $self->status_message( "Attempting to run with 2 args: " . $cmdline . "\n");
        Genome::Utility::FileSystem->shellcmd(
            cmd                         => $cmdline,
            input_files                 => [$reference_bowtie_index_path, $input_pathnames[0], $input_pathnames[1]],
            output_files                => [$output_file],
            skip_if_output_is_present   => 0,
        );

    }
    else {

        $self->error_message("Input pathnames shouldn't have more than 2...: " . Data::Dumper::Dumper(\@input_pathnames) );
        die $self->error_message;

    }
    return 1;
}

sub aligner_params_for_sam_header {
    my $self = shift;

    return "bowtie " . $self->aligner_params;
    # for bwa this looks like "bwa aln -t4; bwa samse 12345'
}
