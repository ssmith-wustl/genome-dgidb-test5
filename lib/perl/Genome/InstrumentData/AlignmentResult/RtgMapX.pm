package Genome::InstrumentData::AlignmentResult::RtgMapX;

use strict;
use warnings;
use File::Basename;
use File::Path;
use File::Copy;
use Genome;

class Genome::InstrumentData::AlignmentResult::RtgMapX{
    is => 'Genome::InstrumentData::AlignmentResult',
    
    has_constant => [
        aligner_name => { value => 'rtg map x', is_param=>1 },
    ],
    has => [
        _max_read_id_seen => { default_value => 0, is_optional => 1},
        _file_input_option =>   { default_value => 'fastq', is_optional => 1},
    ]
};

sub required_arch_os { 'x86_64' }

sub required_rusage { 
    "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>90000 && mem>16000] span[hosts=1] rusage[tmp=90000, mem=16000]' -M 16000000 -n 4";
}

sub _decomposed_aligner_params {
    my $self = shift;

    # -U = report unmapped reads
    # --read-names print real read names

    $ENV{'RTG_MEM'} = ($ENV{'TEST_MODE'} ? '1G' : '15G');
    $self->status_message("RTG Memory request is $ENV{RTG_MEM}");
    my $aligner_params = ($self->aligner_params || '') . " -U --read-names "; 

    my $cpu_count = $self->_available_cpu_count;
    $aligner_params .= " -T $cpu_count";
    
    return ('rtg_aligner_params' => $aligner_params);
}

sub _run_aligner {
    my $self = shift;
    my @input_pathnames = @_;

    if (@input_pathnames == 1) {
        $self->status_message("_run_aligner called in single-ended mode.");
    } elsif (@input_pathnames == 2) {
        $self->status_message("_run_aligner called in paired-end mode.  We don't actually do paired alignment with MapX though; running two passes.");
    } else {
        $self->error_message("_run_aligner called with " . scalar @input_pathnames . " files.  It should only get 1 or 2!");
        die $self->error_message;
    }


    # get refseq info
    my $reference_build = $self->reference_build;
    
    my $reference_sdf_path = $reference_build->full_consensus_path('sdf'); 
    
    # Check the local cache on the blade for the fasta if it exists.
    if (-e "/opt/fscache/" . $reference_sdf_path) {
        $reference_sdf_path = "/opt/fscache/" . $reference_sdf_path;
    }

    my $sam_file = $self->temp_scratch_directory . "/all_sequences.sam";
    my $sam_file_fh = IO::File->new(">>" . $sam_file );
    my $unaligned_file = $self->temp_scratch_directory . "/unaligned.txt";
    my $unaligned_file_fh = IO::File->new(">>" . $unaligned_file); 

    foreach my $input_pathname (@input_pathnames)
    {
        my $scratch_directory = $self->temp_scratch_directory;
        my $staging_directory = $self->temp_staging_directory;

        #   To run RTG, have to first convert ref and inputs to sdf, with 'rtg format', 
        #   for which you have to designate a destination directory

        #STEP 1 - convert input to sdf
        my $input_sdf = File::Temp::tempnam($scratch_directory, "input-XXX") . ".sdf"; #destination of converted input
        my $output_dir = File::Temp::tempnam($scratch_directory, "output-XXX") . ".sdf";  
        my %output_files = (aligned_file =>"$output_dir/alignments.txt.gz", unaligned_file => "$output_dir/unmapped.txt.gz"); 
        my $rtg_fmt = Genome::Model::Tools::Rtg->path_for_rtg_format($self->aligner_version);
        my $cmd;

        $cmd = sprintf('%s --format=%s -o %s %s',
                $rtg_fmt,
                $self->_file_input_option,
                $input_sdf,
                $input_pathname);  

        Genome::Utility::FileSystem->shellcmd(
                cmd                 => $cmd, 
                input_files         => [$input_pathname],
                output_directories  => [$input_sdf],
                skip_if_output_is_present => 0,
                );

        #check sdf output was created
        $DB::single=1;
        my @idx_files = glob("$input_sdf/*");
        if (!@idx_files > 0) {
            die("rtg formatting of [$input_pathname] failed  with $cmd");
        }

        #STEP 2 - run rtg mapx aligner  
        my %aligner_params = $self->_decomposed_aligner_params;
        my $rtg_mapx = Genome::Model::Tools::Rtg->path_for_rtg_mapx($self->aligner_version);
        my $rtg_aligner_params = (defined $aligner_params{'rtg_aligner_params'} ? $aligner_params{'rtg_aligner_params'} : "");
        $cmd = sprintf('%s -t %s -i %s -o %s %s', 
                $rtg_mapx,
                $reference_sdf_path,
                $input_sdf,
                $output_dir,
                $rtg_aligner_params);

        Genome::Utility::FileSystem->shellcmd(
                cmd          => $cmd,
                input_files  => [ $reference_sdf_path, $input_sdf ],
                output_files => [values (%output_files), "$output_dir/done"],
                skip_if_output_is_present => 0,
                );

        # Copy log files 
        my $log_input = "$output_dir/mapx.log";
        my $log_output = $self->temp_staging_directory . "/rtg_mapx.log";
        $cmd = sprintf('cat %s >> %s', $log_input, $log_output);   

        Genome::Utility::FileSystem->shellcmd(
                cmd          => $cmd,
                input_files  => [ $log_input ],
                output_files => [ $log_output ],
                skip_if_output_is_present => 0
                );

        for (values %output_files) {
            $self->status_message("Moving $_ into staging...");
            unless(move($_, $self->temp_staging_directory)) {
                $self->error_message("Failed moving $_ into staging: $!");
                die $self->error_message;
            }
        }

    } 
    return 1;
}

sub input_chunk_size {
    return 3_000_000;
}

sub _compute_alignment_metrics 
{
    return 1;
}

sub create_BAM_in_staging_directory {
    return 1;
}

sub postprocess_bam_file {
    return 1;
}
