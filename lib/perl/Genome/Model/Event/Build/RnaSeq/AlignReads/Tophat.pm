package Genome::Model::Event::Build::RnaSeq::AlignReads::Tophat;

use strict;
use warnings;

use version;
use Genome;

class Genome::Model::Event::Build::RnaSeq::AlignReads::Tophat {
    is => ['Genome::Model::Event::Build::RnaSeq::AlignReads'],
	has => [
    ],
};

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64 && mem>16000 && tmp>150000] span[hosts=1] rusage[tmp=150000, mem=16000]' -M 16000000 -n 4";
}


sub execute {
    my $self = shift;
    my $alignment_directory = $self->build->accumulated_alignments_directory;
    unless (-d $alignment_directory) {
        Genome::Utility::FileSystem->create_directory($alignment_directory);
    }
    my $aligner = $self->create_aligner_tool;
    unless ($aligner) {
        $self->error_message('Failed to create Tophat aligner tool!');
        return;
    }
    unless ($aligner->execute) {
        $self->error_message('Failed to execute Tophat aligner!');
        return;
    }
    my $fastq_dir = $self->build->accumulated_fastq_directory;
    unless (File::Path::rmtree($fastq_dir)) {
        $self->error_message('Failed to remove FASTQ directory: '. $fastq_dir);
        return;
    }
    return 1;
}

sub create_aligner_tool {
    my $self = shift;
    my @instrument_data_assignments = $self->build->instrument_data_assignments;
    my @left_reads;
    my @right_reads;
    my $sum_insert_sizes;
    my $sum_insert_size_std_dev;
    my $sum_read_length;
    my $reads;
    my $fastq_format;
    for my $instrument_data_assignment (@instrument_data_assignments) {
        my $instrument_data = $instrument_data_assignment->instrument_data;

        #Resolved the FASTQ format for quality param
        my $quality_converter = $instrument_data->resolve_quality_converter;
        my $lane_fastq_format;
        if ($quality_converter eq 'sol2phred') {
            $lane_fastq_format = 'solexa1.3-quals';
        } elsif ($quality_converter eq 'sol2sanger') {
            $lane_fastq_format = 'solexa-quals';
        }
        unless ($fastq_format) {
            $fastq_format = $lane_fastq_format;
        } elsif ($fastq_format ne $lane_fastq_format) {
            $self->error_message('Failed to resolve the fastq format between '. $fastq_format .' and '. $lane_fastq_format);
            die($self->error_message);
        }

        # Not the best way to do this, but use the event per instrument data to get the file locations
        # Eventually this could happen in /tmp with only 1-4 lanes of data
        my $prepare_reads = Genome::Model::Event::Build::RnaSeq::PrepareReads->get(
            model_id => $self->model_id,
            build_id => $self->build_id,
            instrument_data_id => $instrument_data->id,
        );
        my $fastq_directory = $prepare_reads->fastq_directory;
        my $left_reads = $fastq_directory.'/'. $instrument_data->read1_fastq_name;
        #The fastq files are now removed after alignment
        #unless (-s $left_reads) {
        #    $self->error_message('Failed to find left reads '. $left_reads);
        #    return;
        #}
        push @left_reads, $left_reads;
        my $right_reads = $fastq_directory.'/'. $instrument_data->read2_fastq_name;
        #The fastq files are now removed after alignment
        #unless (-s $right_reads) {
        #    $self->error_message('Failed to find right reads '. $right_reads);
        #    return;
        #}
        push @right_reads, $right_reads;
        my $median_insert_size = $instrument_data->median_insert_size;
        my $sd_above_insert_size = $instrument_data->sd_above_insert_size;
        # Use the number of reads to somewhat normalize the averages we will calculate later
        # This is not the best approach, any ideas?
        my $clusters = $instrument_data->clusters;
        if ($median_insert_size && $sd_above_insert_size) {
            $sum_insert_sizes += ($median_insert_size * $clusters);
            $sum_insert_size_std_dev += ($sd_above_insert_size * $clusters);
        } else {
            # These seem like reasonable default values given most libraries are 300-350bp
            $sum_insert_sizes += (300 * $clusters);
            $sum_insert_size_std_dev += (20 * $clusters);
        }
        # TODO: This could be skewed if Read 2 is conconcatanated or trimmed reads are used
        $sum_read_length += ($instrument_data->read_length * $clusters);
        $reads += $clusters;
    }
    unless ($reads) {
        $self->error_message('Failed to calculate the number of reads across all lanes');
        return;
    }
    unless ($sum_insert_sizes) {
        $self->error_message('Failed to calculate the sum of insert sizes across all lanes');
        return;
    }
    unless ($sum_insert_size_std_dev) {
        $self->error_message('Failed to calculate the sum of insert size standard deviation across all lanes');
        return;
    }
    unless ($sum_read_length) {
        $self->error_message('Failed to calculate the sum of read lengths across all lanes');
        return;
    }
    my $avg_read_length = int($sum_read_length / $reads);
    # The inner-insert size should be the predicted external-insert size(300) minus the read lengths(2x100=200). Example: 300-200=100
    my $insert_size = int( $sum_insert_sizes / $reads ) - $avg_read_length;
    unless ($insert_size) {
        $self->error_message('Failed to get insert size with '. $reads .' reads and a sum insert size of '. $sum_insert_sizes);
        return;
    }
    # TODO: averaging the standard deviations does not seem statisticly sound
    my $insert_size_std_dev = int( $sum_insert_size_std_dev / $reads );
    unless ($insert_size_std_dev) {
        $self->error_message('Failed to get insert size with '. $reads .' $reads and a sum insert size standard deviation of '. $sum_insert_size_std_dev);
        return;
    }

    my $reference_build = $self->model->reference_sequence_build;
    my $aligner_params = $self->model->read_aligner_params || '';
    my $read_1_fastq_list = join(',',@left_reads);
    my $read_2_fastq_list = join(',',@right_reads);
    my $reference_path = $reference_build->full_consensus_path('bowtie');
    my $suffix = 'gff3';
    if (version->parse($self->model->read_aligner_version) >= version->parse('1.1.0')) {
        $suffix = 'gtf';
    }

    # DEFAULT SHOULD BE: NCBI-human.combined-annotation/54_36p_v2
    my $annotation_reference_transcripts = $self->model->annotation_reference_transcripts;

    my ($annotation_name,$annotation_version) = split(/\//, $annotation_reference_transcripts);
    my $annotation_model = Genome::Model->get(name => $annotation_name);
    unless ($annotation_model){
        $self->error_message('Failed to get annotation model for annotation_reference_transcripts: ' . $annotation_reference_transcripts);
        return;
    }

    unless (defined $annotation_version) {
        $self->error_message('Failed to get annotation version from annotation_reference_transcripts: '. $annotation_reference_transcripts);
        return;
    }

    my $annotation_build = $annotation_model->build_by_version($annotation_version);
    unless ($annotation_build){
        $self->error_message('Failed to get annotation build from annotation_reference_transcripts: '. $annotation_reference_transcripts);
        return;
    }

    my $transcripts_path = $annotation_build->annotation_file($suffix);
    if ($transcripts_path && -f $transcripts_path) {
        $aligner_params .= ' -G '. $transcripts_path;
    }
    $aligner_params .= ' --'. $fastq_format;
    unless ($reference_path) {
        $self->error_message('Need to make bowtie reference index in directory: '. $reference_build->data_directory);
        return;
    }
    my %params = (
        reference_path => $reference_path,
        read_1_fastq_list => $read_1_fastq_list,
        read_2_fastq_list => $read_2_fastq_list,
        insert_size => $insert_size,
        insert_std_dev => $insert_size_std_dev,
        aligner_params => $aligner_params,
        alignment_directory => $self->build->accumulated_alignments_directory,
        use_version => $self->model->read_aligner_version,
    );
    my $tool = Genome::Model::Tools::Tophat::AlignReads->create(%params);
    unless ($tool) {
        $self->error_message('Failed to create tophat aligner tool with params:  '. Data::Dumper::Dumper(%params));
        return;
    }
    return $tool;
}

sub verify_successful_completion {
    my $self = shift;
    warn ('Please implement vsc for class '. __PACKAGE__);
    return 1;
}

1;
