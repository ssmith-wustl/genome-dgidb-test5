package Genome::Model::Tools::RefCov;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RefCov {
    is => ['Command'],
    has_input => [
        alignment_file_path => {
            is => 'String',
            doc => 'The path to the alignment file path.',
        },
        alignment_file_format => {
            is => 'String',
            doc => 'The format of the alignment file.',
            default_value => 'bam',
            valid_values => ['bam'],
            is_optional => 1,
        },
        roi_file_path => {
            is => 'String',
            doc => 'The format of the region-of-interest file.',
        },
        roi_file_format => {
            is => 'String',
            doc => 'The format of the region-of-interest file.',
            default_value => 'bed',
            valid_values => ['bed'],
            is_optional => 1,
        },
        min_depth_filter => {
            is => 'String',
            doc => 'The minimum depth at each position to consider coverage.  For more than one, supply a comma delimited list(ie. 1,5,10,15,20)',
            default_value => 1,
        },
        wingspan => {
            is => 'Integer',
            doc => 'A base pair wingspan value to add +/- of the input regions',
            default_value => 0,
            is_optional => 1,
        },
        min_base_quality => {
            is => 'Integer',
            doc => 'only consider bases with a minimum phred quality',
            default_value => 0,
            is_optional => 1,
        },
        min_mapping_quality => {
            is => 'Integer',
            doc => 'only consider alignments with minimum mapping quality',
            default_value => 0,
            is_optional => 1,
        },
        genome_normalized_coverage => {
            is => 'Boolean',
            doc => 'Normalized coverage based on average depth across entire reference genome.',
            default_value => 0,
            is_optional => 1,
        },
        roi_normalized_coverage => {
            is => 'Boolean',
            doc => 'Normalized coverage based on average depth across supplied regions-of-interest.',
            default_value => 0,
            is_optional => 1,
        },
        evaluate_gc_content => {
            is => 'Boolean',
            doc => 'Evaluate G+C content of the defined regions-of-interest.',
            default_value => 0,
            is_optional => 1,
        },
        output_directory => {
            doc => 'When run in parallel, this directory will contain all output and intermediate STATS files. Sub-directories will be made for wingspan and min_depth_filter params. Do not define if stats_file is defined.',
            is_optional => 1,
        },
    ],
    has_output => [
        stats_file => {
            doc => 'When run in parallel, do not define.  From the command line this file will contain the output metrics for each region.',
            is_optional => 1,
        },
        final_directory => {
            doc => 'The directory where parallel output is written to when wingspan is defined in parallel fashion',
            is_optional => 1,
        },
    ],
    has_param => [
        lsf_queue => {
            doc => 'When run in parallel, the LSF queue to submit jobs to.',
            is_optional => 1,
            default_value => 'apipe',
        },
        lsf_resource => {
            doc => 'When run in parallel, the resource request necessary to run jobs on LSF.',
            is_optional => 1,
            default_value => "-R 'select[type==LINUX64]'",
        },
    ],
    has_optional => [
        _alignments => {},
        _roi => {},
    ],
};

sub help_brief {
    "Tools to run the Ref-Cov tookit.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt ref-cov ...    
EOS
}

sub help_detail {
    return <<EOS 
Please add help detail!
EOS
}

# NOTE: I doubt we ever support anything but BAM.  If we do, some common adaptor/iterator will be necessary to do something like $alignments->next_alignment
sub load_alignments {
    my $self = shift;
    my $alignments;
    if ($self->alignment_file_format eq 'bam') {
        $alignments  = Genome::RefCov::Bam->create(bam_file => $self->alignment_file_path );
        unless ($alignments) {
            die('Failed to load alignment file '. $self->alignment_file_path);
        }
    } else {
        die('Failed to load '. $self->alignment_file_format .' file '. $self->alignment_file_path);
    }
    $self->_alignments($alignments);
    return $alignments;
}

sub load_roi {
    my $self = shift;
    # TODO: Can the class Genome::RefCov::ROI or a new class Genome::RefCov::ROI::File resolve the appropriate adaptor based on the file type?
    my $format = $self->roi_file_format;
    my $subclass = ucfirst($format);
    my $class = 'Genome::RefCov::ROI::'. $subclass;
    my $regions = $class->create(
        file => $self->roi_file_path,
        wingspan => $self->wingspan,
    );
    unless ($regions) {
        die('Failed to load '. $self->roi_file_format .' regions-of-interest file '. $self->roi_file_path );
    }
    $self->_roi($regions);
    return $regions;
}

# This is only necessary when running in parallel as a part of a workflow
# There is probably a better way of doing this
sub resolve_final_directory {
    my $self = shift;

    my $output_directory = $self->output_directory;
    if ($output_directory) {
        my $wingspan = $self->wingspan;
        if (defined($wingspan)) {
            $output_directory .= '/wingspan_'. $wingspan;
        }
        unless (-d $output_directory){
            unless (Genome::Utility::FileSystem->create_directory($output_directory)) {
                die('Failed to create output directory '. $output_directory);
            }
        }
        $self->final_directory($output_directory);
    }
    return 1;
}

# This is only necessary when running in parallel as a part of a workflow
# There is probably a better way of doing this
sub resolve_stats_file {
    my $self = shift;
    unless (defined($self->stats_file)) {
        unless (defined($self->output_directory)) {
            die('Failed to define output_directory or stats_file!');
        }
        my $alignment_file_expected_suffix = '.'. $self->alignment_file_format;
        my ($alignment_basename,$alignment_dirname,$alignment_suffix) = File::Basename::fileparse($self->alignment_file_path,[$alignment_file_expected_suffix]);
        unless (defined($alignment_suffix)) {
            die('Failed to recognize file '. $self->alignment_file_path .' without expected suffix '. $alignment_file_expected_suffix);
        }
        my $roi_file_expected_suffix = '.'. $self->roi_file_format;
        my ($regions_basename,$roi_dirname,$roi_suffix) = File::Basename::fileparse($self->roi_file_path,[$roi_file_expected_suffix]);
        unless (defined($roi_suffix)) {
            die('Failed to recognize file '. $self->roi_file_path .' without bed suffix');
        }
        $self->stats_file($self->final_directory .'/'. $alignment_basename .'_'. $regions_basename .'_STATS.tsv');
    }
    return 1;
}

sub region_coverage_array_ref {
    my $self = shift;
    my $region = shift;

    my $bam = $self->_alignments->bio_db_bam;
    my $index = $self->_alignments->bio_db_index;
    my $tid = $self->_alignments->tid_for_chr($region->chrom);

    my $coverage;
    if ($self->min_base_quality || $self->min_mapping_quality) {
        $coverage = $self->region_coverage_with_quality_filter($region);
    } else {
        # low-level API uses zero based coordinates
        # all regions should be zero based, but for some reason the correct length is never returned
        # the API must be expecting BED like inputs where the start is zero based and the end is 1-based
        # you can see in the docs for the low-level Bio::DB::BAM::Alignment class that start 'pos' is 0-based,but calend really returns 1-based
        $coverage = $index->coverage( $bam, $tid, ($region->start - 1), $region->end);
    }
    unless (scalar( @{ $coverage } ) == $region->length) {
        die('The length of region '. $region->name .' '. $region->chrom .':'. $region->start .'-'. $region->end
                .'('. $region->length .') does not match the coverage array length '. scalar( @{ $coverage }));
    }
    return $coverage;
}

sub region_coverage_with_quality_filter {
    my $self = shift;
    my $region = shift;

    my $bam = $self->_alignments->bio_db_bam;
    my $index = $self->_alignments->bio_db_index;
    my $tid = $self->_alignments->tid_for_chr($region->chrom);
    my $min_mapping_quality = $self->min_mapping_quality;
    my $min_base_quality = $self->min_base_quality;
    my $quality_coverage_callback = sub {
        my ($tid,$pos,$pileups,$data) = @_;
        my ($start,$end,$coverage) = @$data;
        #Here the position $pos is always zero-based, but the end position has to be 1-based in the coverage function
        if ($pos < $start || $pos >= $end) { return; }
        my $index = $pos - $start;
        for my $pileup (@$pileups) {
            my $base_position = $pileup->qpos;
            my $alignment = $pileup->alignment;
            if ($min_mapping_quality) {
                unless ($alignment->qual >= $min_mapping_quality) {
                    next;
                }
            }
            my @base_qualities = $alignment->qscore;
            my $quality = $base_qualities[$base_position];
            if ($quality >= $min_base_quality) {
                @$coverage[$index]++;
            }
        }
    };
    #Start with an empty array of zeros
    my @coverage = map { 0 } (1 .. $region->length);
    my $coverage = \@coverage;
    # the pileup callback will add each base gt or eq to the quality_filter to the index position in the array ref
    $index->pileup($bam,$tid,($region->start - 1),$region->end,$quality_coverage_callback,[($region->start - 1),$region->end,$coverage]);
    return $coverage;
}

sub print_standard_roi_coverage {
    my $self = shift;

    my $regions = $self->load_roi;
    my $alignments = $self->load_alignments;

    my $temp_stats_file = Genome::Utility::FileSystem->create_temp_file_path;
    open( my $stats_fh, '>'. $temp_stats_file ) || die 'Failed to open stats file for writing '. $temp_stats_file;

    my $bam  = $alignments->bio_db_bam;
    my $index = $alignments->bio_db_index;

    my @min_depths = split(',',$self->min_depth_filter);
    my @chromosomes = $regions->chromosomes;
    for my $chrom (@chromosomes) {
        my @regions = $regions->chromosome_regions($chrom);
        for my $region (@regions) {
            my $coverage_array_ref = $self->region_coverage_array_ref($region);
            for my $min_depth (@min_depths) {
                my $stat = Genome::RefCov::Stats->create(
                    coverage => $coverage_array_ref,
                    min_depth => $min_depth,
                );
                print $stats_fh $region->name ."\t". $stat->as_string . "\n";
            }
        }
    }
    $stats_fh->close;

    Genome::Utility::FileSystem->copy_file($temp_stats_file, $self->stats_file);
    return 1;
}

1;
