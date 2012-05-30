package Genome::InstrumentData::AlignmentResult::PerLaneTophat;

use strict;
use warnings;

use Genome;


class Genome::InstrumentData::AlignmentResult::PerLaneTophat {
    is => 'Genome::InstrumentData::AlignmentResult',
    has_constant => [
        aligner_name => {
            value => 'tophat',
            is_param => 1
        },
    ],
    has_calculated => [
        bowtie_version => {
            is => "Text",
            calculate => \&_get_bowtie_version,
            calculate_from => ['class', 'aligner_params'],
            doc => 'the version of bowtie passed in - will need to be translated into appropriate tophat params'
        },
    ]
};

sub required_arch_os { 'x86_64' }

sub required_rusage {
     "-R 'select[model!=Opteron250 && type==LINUX64 && mem>16000 && tmp>150000] span[hosts=1] rusage[tmp=150000, mem=16000]' -M 16000000 -n 4";
}

sub _run_aligner {
    my $self = shift;
    my @input_pathnames = @_;


    # get refseq info
    my $reference_build = $self->reference_build;
    # This is your scratch directory.  Whatever you put here will be wiped when the alignment
    # job exits.
    my $scratch_directory = $self->temp_scratch_directory;
    # This is the alignment output directory.  Whatever you put here will be synced up to the
    # final alignment directory that gets a disk allocation.
    my $staging_directory = $self->temp_staging_directory;

    my $tophat_cmd = $self->_get_tophat_cmd(\@input_pathnames);

    #TODO - in tophat 1.4 and later - the unaligned reads are output in fastq files already
    #in those cases we shouldn't need to go through the Picard MergeBamAlignment stuff
    #we can just combine the files

    if($self->instrument_data->can("bam_path") && -e $self->instrument_data->bam_path){
        Genome::Sys->create_symlink($self->instrument_data->bam_path, "$scratch_directory/unaligned.bam");
    }else{
        my $fastq_to_sam_cmd = Genome::Model::Tools::Picard::FastqToSam->create(
            fastq  => $input_pathnames[0],
            fastq2 => $input_pathnames[1],
            output => "$scratch_directory/unaligned.bam",
            quality_format => 'Standard',
            sort_order => 'queryname',
            use_version => $self->picard_version,
        );

        unless($fastq_to_sam_cmd->execute()){
            die($self->error_message('Unable to create sam file from fastqs'));
        }
    }

    Genome::Sys->shellcmd(
        cmd => $tophat_cmd,
        input_files => \@input_pathnames,
        output_files => [ "$staging_directory/accepted_hits.bam" ]
    );

    rename("$staging_directory/accepted_hits.bam", "$scratch_directory/accepted_hits.bam");

    my $bam_with_unaligned_reads_cmd = Genome::Model::Tools::Picard::MergeBamAlignment->create(
        unmapped_bam => "$scratch_directory/unaligned.bam",
        aligned_bam => "$scratch_directory/accepted_hits.bam",
        output_file => "$scratch_directory/all_reads.bam",
        reference_sequence => $self->get_reference_sequence_index->full_consensus_path('fa'),
        paired_run => scalar(@input_pathnames) eq 2,
        max_insertions_or_deletions => -1,
        use_version => $self->picard_version,
    );

    unless($bam_with_unaligned_reads_cmd->execute()){
        die($self->error_message("Unable to create a merged bam with both aligned and unaligned reads."));
    }

    #TODO tophat 2.0.1 and later will add readgroup tags automatically

    my $sam_file = $scratch_directory . "/all_sequences.sam";

    my $samtools_view_cmd = Genome::Model::Tools::Sam::BamToSam->create(
        sam_file => $sam_file,
        bam_file => "$scratch_directory/all_reads.bam",
        include_headers => 0,
        use_version => $self->samtools_version,
    );

    unless($samtools_view_cmd->execute()){
        die($self->error_message("Unable to convert bam to sam."));
    }

    unless (-s $sam_file) {
        die "The sam output file $sam_file is zero length; something went wrong.";
    }

    #promote other misc tophat result files - converted sam will be handled downstream
    rename("$scratch_directory/junctions.bed", "$staging_directory/junctions.bed");
    rename("$scratch_directory/insertions.bed", "$staging_directory/insertions.bed");
    rename("$scratch_directory/deletions.bed", "$staging_directory/deletions.bed");
    rename("$scratch_directory/logs", "$staging_directory/logs");

    return 1;
}

sub aligner_params_for_sam_header {
    my $self = shift;
    return "tophat " . $self->aligner_params;
}

sub aligner_params_required_for_index {
    return 1;
}

# Does your aligner set MD tags?  If so this should return 0, otherwise 1
sub fillmd_for_sam {
    return 0;
}

# If your aligner adds read group tags, or you are handling it in the wrapper, this needs to be 0
# otherwise 1.  If you are streaming output straight to BAM then you need to take care of adding RG
# tags with either the wrapper or the aligner itself, and this needs to be 0.
sub requires_read_group_addition {
    return 1;
}

# if you are streaming to bam, set this to 1.  Beware of read groups.
sub supports_streaming_to_bam {
    return 0;
}

# If your aligner accepts BAM files as inputs, return 1.  You'll get a set of BAM files as input, with
# suffixes to define whether it's paired or unparied.
# [input_file.bam:0] implies SE, [input_file.bam:1, input_file.bam:2] implies paired.
sub accepts_bam_input {
    return 0;
}

# Use this to prep the index.  Indexes are saved for each combo of aligner params & version, as runtime
# params for some aligners also call for specific params when building the index.
sub prepare_reference_sequence_index {
    my $class = shift;
    my $refindex = shift;

    # If you need the parameters the aligner is being run with, in order to customize the index, here they are.
    my $aligner_params = $refindex->aligner_params;

    my $staging_dir = $refindex->temp_staging_directory;
    my $staged_fasta_file = sprintf("%s/all_sequences.fa", $staging_dir);

    Genome::Sys->create_symlink($refindex->reference_build->get_sequence_dictionary, $staging_dir ."/all_sequences.dict" );

    my $bowtie_index = Genome::Model::Build::ReferenceSequence::AlignerIndex->get_or_create(
        reference_build_id => $refindex->reference_build_id,
        aligner_name => 'bowtie',
        aligner_version => $class->_get_bowtie_version($aligner_params),
    );

    for my $filepath (glob($bowtie_index->output_dir . "/*")){
        my $filename = File::Basename::fileparse($filepath);
        Genome::Sys->create_symlink($filepath, $staging_dir . "/$filename");
    }

    $bowtie_index->add_user(
        label => 'uses',
        user => $refindex
    );

    my $actual_fasta_file = $staged_fasta_file;

    if (-l $staged_fasta_file) {
        $class->status_message(sprintf("Following symlink for fasta file %s", $staged_fasta_file));
        $actual_fasta_file = readlink($staged_fasta_file);
        unless($actual_fasta_file) {
            $class->error_message("Can't read target of symlink $staged_fasta_file");
            return;
        }
    }

    return 1;
}

sub _get_bowtie_version {
    my ($class, $aligner_params) = @_;
    $aligner_params =~ /--bowtie-version(?:\s+|=)(.+?)(?:\s+|$)/i;
    return $1;
}

sub _get_modified_tophat_params{
    my $self = shift;
    my $params = $self->aligner_params;
    $params =~ s/--bowtie-version(?:\s+|=)(.+?)(?:\s+|$)//i;
    unless ($1 =~ /^2/) {
        $params .= " --bowtie1";
    }
    return $params;
}

sub _get_tophat_cmd {
    my $self = shift;
    my $input_filenames = shift;
    die("More than 2 input files cannot be specified!") unless $#$input_filenames < 2;
    my $path = Genome::Model::Tools::Tophat->path_for_tophat_version($self->aligner_version);
    my $cmd =  $path . " " . $self->_get_modified_tophat_params . " -o " . $self->temp_staging_directory;
    $cmd .=  " "  . $self->get_reference_sequence_index->full_consensus_path('fa') . " " . join(" " , @$input_filenames);
    return $cmd;
}

1;
