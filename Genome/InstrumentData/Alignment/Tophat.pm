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

    unless ( $self->arch_os =~ /64/ ) {
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
    $self->status_message("OUTPUT PATH: $alignment_directory\n");


    # we resolve these first, since we might just print the paths we work with then exit
    my @input_pathnames = $self->sanger_fastq_filenames;
    $self->status_message("INPUT PATH(S): @input_pathnames\n");

    # prepare the refseq
    my $ref_seq_file =  $reference_build->full_consensus_path('bowtie');
    unless ($ref_seq_file) {
        $self->error_message('Failed to find full consensus path for reference build '. $reference_build->name);
        die($self->error_message);
    }
    #TODO:  A check for bowtie index files could be added to the reference placeholder...
    my $ref_seq_index_file =  $ref_seq_file .'.1.ebwt';
    unless (-e $ref_seq_index_file) {
        $self->error_message("Reference build index path '$ref_seq_index_file' does not exist.");
        die($self->error_message);
    }
    $self->status_message("REFSEQ PATH: $ref_seq_file\n");

    my $is_paired_end;
    my $insert_size;
    my $insert_sd;
    if ($instrument_data->is_paired_end && !$self->force_fragment) {
        $insert_sd = $instrument_data->sd_above_insert_size;
        $insert_size = $instrument_data->median_insert_size;
        $is_paired_end = 1;
    } else {
        $is_paired_end = 0;
    }

    # these are general params not infered from the above
    my $aligner_output_file = $self->aligner_output_file;
    my $aligner_params = $self->aligner_params;

    #if ($instrument_data->resolve_quality_converter eq 'sol2phred') {
    #    $aligner_params .= ' --solexa1.3-quals';
    #} elsif ($instrument_data->resolve_quality_converter eq 'sol2sanger') {
    #    $aligner_params .= ' --solexa-quals';
    #} else {
    #    $self->error_message('Failed to resolve fastq quality coversion!');
    #    die($self->error_message);
    #}

    # RESOLVE A STRING OF ALIGNMENT PARAMETERS
    if ($is_paired_end && $insert_size && $insert_sd) {
        #The standard deviation is the above instert size deviation, does below insert size stdev matter?
        $aligner_params .= ' --mate-inner-dist '. $insert_size .' --mate-std-dev '. $insert_sd;
    }

    my $files_to_align = join(' ',@input_pathnames);

    my $cmdline = Genome::Model::Tools::Tophat->path_for_tophat_version($self->aligner_version)
    . sprintf(' --output-dir %s %s %s %s ',
              $alignment_directory,
              $aligner_params,
              $ref_seq_file,
              $files_to_align) .' > '. $aligner_output_file .' 2>&1';
    my @input_files = ($ref_seq_file, @input_pathnames);

    $self->status_message("COMMAND: $cmdline\n");
    Genome::Utility::FileSystem->shellcmd(
                                          cmd                         => $cmdline,
                                          input_files                 => \@input_files,
                                          output_files                => [$self->sam_file],
                                          allow_zero_size_output_files => 1,
                                          skip_if_output_is_present   => 1,
                                      );

    my $sam_to_bam = Genome::Model::Tools::Sam::SamToBam->execute(
        sam_file    => $self->sam_file,
        bam_file    => $self->bam_file,
        ref_list    => $reference_build->full_consensus_sam_index_path,
        is_sorted   => 0,
        index_bam   => 1,
        fix_mate    => 0,
        keep_sam    => 0,
    );
    unless ($sam_to_bam) {
        $self->error_message('Error converting SAM file: '. $self->sam_file .' to BAM file '. $self->bam_file);
        die($self->error_message);
    }
    unless ($self->verify_aligner_successful_completion) {
        $self->error_message('Failed to verify Tophat successful completion!');
        die($self->error_message);
    }
    unless (rmtree($self->tmp_tophat_directory)) {
        $self->error_message('Failed to remove tmp tophat directory '. $self->tmp_tophat_directory .":  $!");
        die($self->error_message);
    }
    my @intermediate_files = glob($self->alignment_directory .'/*.fq*');
    for my $intermediate_file (@intermediate_files) {
        unless (unlink($intermediate_file)) {
            $self->error_message('Failed to remove intermediate tophat file '. $intermediate_file .":  $!");
            die($self->error_message);
        }
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

