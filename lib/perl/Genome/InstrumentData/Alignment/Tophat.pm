package Genome::InstrumentData::Alignment::Tophat;

#REVIEW fdu 11/17/2009
#Implement the method "get_alignment_statistics". Currently it returns
#nothing and contains only nonsense codes

use strict;
use warnings;

use Genome;
use File::Path;

class Genome::InstrumentData::Alignment::Tophat {
    is => ['Genome::InstrumentData::Alignment'],
    has_constant => [
        aligner_name => { value => 'tophat' },
    ],
};

sub input_pathnames {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    my %params;
    if ($self->force_fragment) {
        if ($self->instrument_data_id eq $self->_fragment_seq_id) {
            $params{paired_end_as_fragment} = 2;
        } else {
            $params{paired_end_as_fragment} = 1;
        }
    }
    my @fastq_pathnames = $instrument_data->fastq_filenames(%params);
    return @fastq_pathnames;
}


sub aligner_output_file {
    my $self = shift;
    return $self->alignment_directory .'/tophat.aligner_output';
}

sub sam_file {
    my $self = shift;
    return $self->alignment_directory .'/accepted_hits.sam';
}

sub bam_file {
    my $self = shift;
    return $self->alignment_directory .'/accepted_hits.bam';
}

sub coverage_file {
    my $self = shift;
    return $self->alignment_directory .'/coverage.wig';
}

sub junctions_file {
    my $self = shift;
    return $self->alignment_directory .'/junctions.bed';
}

sub tmp_tophat_directory {
    my $self = shift;
    return $self->alignment_directory .'/tmp';
}

sub output_files {
    my $self = shift;
    my @output_files;
    for my $method (qw/aligner_output_file bam_file coverage_file junctions_file/) {
        push @output_files, $self->$method;
    }
    return @output_files;
}

sub estimated_kb_usage {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    unless ($instrument_data->calculate_alignment_estimated_kb_usage) {
        return;
    } else {
        return ($instrument_data->calculate_alignment_estimated_kb_usage * 10);
    }
}

sub find_or_generate_alignment_data {
    my $self = shift;

    unless ($self->verify_alignment_data) {
        $self->_run_aligner();
    } else {
        $self->status_message("Existing alignment data is available and deemed correct.");
    }

    return 1;
}


sub verify_alignment_data {
    my $self = shift;

    my $alignment_dir = $self->alignment_directory;
    return unless $alignment_dir;
    return unless -d $alignment_dir;

    unless ( Genome::Config->arch_os =~ /64/ ) {
        die('Failed to verify_alignment_data.  Must run from 64-bit architecture.');
    }

    my $lock;
    unless ($self->_resource_lock) {
        $lock = $self->lock_alignment_resource;
    } else {
        $lock = $self->_resource_lock;
    }

    my @existing_output_files =  grep {-e} $self->output_files;
    unless (@existing_output_files) {
        return;
    }
    unless($self->verify_aligner_successful_completion) {
        $self->error_message('Failed to verify aligner successful completion');
        $self->die_and_clean_up($self->error_message);
    }
    $self->status_message('Alignment data verified: '. $alignment_dir);

    unless ($self->unlock_alignment_resource) {
        $self->error_message('Failed to unlock alignment resource '. $lock);
        return;
    }
    return 1;
}

sub _run_aligner {
    my $self = shift;

    my $lock;
    unless ($self->_resource_lock) {
        $lock = $self->lock_alignment_resource;
    } else {
        $lock = $self->_resource_lock;
    }

    my $instrument_data = $self->instrument_data;
    my $reference_build = $self->reference_build;
    my $alignment_directory = $self->alignment_directory;
    my @input_pathnames = $self->input_pathnames;
    my %align_params = (
        read_1_fastq_list => $input_pathnames[0],
        reference_path => $reference_build->full_consensus_path('bowtie'),
        use_version => $self->aligner_version,
        alignment_directory => $alignment_directory,
    );
    if (scalar(@input_pathnames) > 1) {
        $align_params{'read_2_fastq_list'} = $input_pathnames[1];
        $align_params{'insert_size'} = $instrument_data->median_insert_size;
        $align_params{'insert_std_dev'} = $instrument_data->sd_above_insert_size;
    }
    if ($self->aligner_params) {
        $align_params{'aligner_params'} = $self->aligner_params;
    }
    unless (Genome::Model::Tools::Tophat::AlignReads->execute(%align_params)) {
        $self->die_and_clean_up('Failed to run Tophat AlignReads with params: '. Data::Dumper::Dumper(%align_params));
    }
    return 1;
}

sub process_low_quality_alignments {
    my $self = shift;
    $self->die_and_clean_up('Please implement process_low_quality_alignments for '. __PACKAGE__);
}

sub verify_aligner_successful_completion {
    my $self = shift;

    my @output_files = $self->output_files;
    for my $output_file (@output_files) {
        unless (-e $output_file) {
            $self->error_message("Alignment output file '$output_file' not found.");
            return;
        }
    }
    #TODO: Find a line in the aligner output that
    # 1.) denotes paired end alignment
    #Otherwise the file existence check is already occuring in shellcmd
    
    #my $instrument_data = $self->instrument_data;
    #if ($instrument_data->is_paired_end) {
        #my $stats = $self->get_alignment_statistics($aligner_output_file);
        #unless ($stats) {
        #    return;
        #}
        #if ($self->force_fragment) {
            #if (defined($$stats{'Paired Reads'})) {
                #$self->error_message('Paired-end instrument data '. $instrument_data->id .' was not aligned as fragment data according to aligner output '. $aligner_output_file);
                #return;
            #}
        #}  else {
            #if (!defined($$stats{'Paired Reads'})) {
                #$self->error_message('Paired-end instrument data '. $instrument_data->id .' was not aligned as paired end data according to aligner output '. $aligner_output_file);
                #return;
            #}
        #}
    #}
    my $aligner_output_fh = Genome::Utility::FileSystem->open_file_for_reading($self->aligner_output_file);
    unless ($aligner_output_fh) {
        $self->error_message('Failed to open aligner output file '. $self->aligner_output_file .":  $!");
        return;
    }
    while(<$aligner_output_fh>) {
        if (m/^Run complete/) {
            $aligner_output_fh->close();
            return 1;
        }
    }
    $aligner_output_fh->close();
    return;
}

sub get_alignment_statistics {
    my $self = shift;

    #TODO: Implement this method for tophat
    return;

    my $aligner_output_file = shift;
    unless ($aligner_output_file) {
        $aligner_output_file = $self->alignment_file;
    }
    unless (-s $aligner_output_file) {
        $self->error_message("Aligner output file '$aligner_output_file' not found or zero size.");
        return;
    }

    my $fh = Genome::Utility::FileSystem->open_file_for_reading($aligner_output_file);
    unless($fh) {
        $self->error_message("unable to open maq's alignment output file:  " . $aligner_output_file);
        return;
    }
    my @lines = $fh->getlines;
    $fh->close;
    my %hashy_hash_hash;
    my @comments = grep { /^#/ } @lines;
    foreach my $comment (@comments) {
        $comment =~ /^#\s+(.*)\:\s+(.*)/;
        my $key = $1;
        my $value = $2;
        if ($key && $value) {
            $hashy_hash_hash{$key} = $value;
        }
    }
    return \%hashy_hash_hash;
}



1;

