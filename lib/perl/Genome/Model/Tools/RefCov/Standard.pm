package Genome::Model::Tools::RefCov::Standard;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RefCov::Standard {
    is => ['Genome::Model::Tools::RefCov'],
    has_input => [
        output_directory => {
            doc => 'When run in parallel, this directory will contain all output and intermediate STATS files. Sub-directories will be made for wingspan and min_depth_filter params. Do not define if stats_file is defined.',
            is_optional => 1,
        },
        min_depth_filter => {
            doc => 'The minimum depth at each position to consider coverage.  For more than one, supply a comma delimited list(ie. 1,5,10,15,20)',
            default_value => 1,
            is_optional => 1,
        },
        wingspan => {
            doc => 'A base pair wingspan value to add +/- of the input regions',
            default_value => 0,
            is_optional => 1,
        },
        min_base_quality => {
            doc => 'only consider bases with a minimum phred quality',
            default_value => 0,
            is_optional => 1,
        },
        min_mapping_quality => {
            doc => 'only consider alignments with minimum mapping quality',
            default_value => 0,
            is_optional => 1,
        }
    ],
    has_output => [
        stats_file => {
            doc => 'When run in parallel, do not define.  From the command line this file will contain the output metrics for each region.',
            is_optional => 1,
        },
        final_directory => {
            doc => 'The directory where parallel output is written to',
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
};

sub help_detail {
'
These commands are setup to run perl v5.10.0 scripts that use Bio-Samtools and require bioperl v1.6.0.  They all require 64-bit architecture.

Output file format(stats_file):
[1] Region Name (column 4 of BED file)
[2] Percent of Reference Bases Covered
[3] Total Number of Reference Bases
[4] Total Number of Covered Bases
[5] Number of Missing Bases
[6] Average Coverage Depth
[7] Standard Deviation Average Coverage Depth
[8] Median Coverage Depth
[9] Number of Gaps
[10] Average Gap Length
[11] Standard Deviation Average Gap Length
[12] Median Gap Length
[13] Min. Depth Filter
[14] Discarded Bases (Min. Depth Filter)
[15] Percent Discarded Bases (Min. Depth Filter)
';
}

sub execute {
    my $self = shift;
    unless ($] > 5.012) {
        die "Bio::DB::Sam requires perl 5.12!";
    }
    require Bio::DB::Sam;
    my $output_directory = $self->output_directory;
    my $wingspan = $self->wingspan;
    if ($output_directory) {
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
    my @min_depths = split(',',$self->min_depth_filter);
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

    my $temp_stats_file = Genome::Utility::FileSystem->create_temp_file_path;

    my $regions = Genome::RefCov::Bed->create(
        file => $self->roi_file_path,
        wingspan => $wingspan,
    );
    unless ($regions) {
        die('Failed to load BED region file '. $self->roi_file_path );
    }
    open( my $stats_fh, '>'. $temp_stats_file ) || die 'Failed to open stats file for writing '. $temp_stats_file;

    # create low level alignment object
    my $refcov_bam  = Genome::RefCov::Bam->create(bam_file => $self->alignment_file_path );
    unless ($refcov_bam) {
        die('Failed to load alignment file '. $self->alignment_file_path);
    }
    my $bam  = $refcov_bam->bio_db_bam;
    my $index = $refcov_bam->bio_db_index;
    my $header = $bam->header();
    
    # Number of reference sequences
    my $targets = $header->n_targets();
    
    # The reference sequence names in an array ref with indexed positions
    my $target_names = $header->target_name();
    
    # at the low level API the seq_id/target_name is meaningless
    # cache the target_names in a hash by actual reference sequence name
    # then we can look up the target index on the fly
    my %target_name_index;
    my $i = 0;
    for my $target_name (@{ $target_names }) {
        $target_name_index{$target_name} = $i++;
    }
    
    # Make sure our index is not off
    unless ($targets == $i) {
        die 'Expected '. $targets .' targets but counted '. $i .' indices';
    }
    
    my $quality_coverage_callback = sub {
        my ($tid,$pos,$pileups,$data) = @_;
        my ($start,$end,$coverage) = @$data;
        #Here the position $pos is always zero-based, but the end position has to be 1-based in the coverage function
        if ($pos < $start || $pos >= $end) { return; }
        my $index = $pos - $start;
        for my $pileup (@$pileups) {
            my $base_position = $pileup->qpos;
            my $alignment = $pileup->alignment;
            if ($self->min_mapping_quality) {
                unless ($alignment->qual >= $self->min_mapping_quality) {
                    next;
                }
            }
            my @base_qualities = $alignment->qscore;
            my $quality = $base_qualities[$base_position];
            if ($quality >= $self->min_base_quality) {
                @$coverage[$index]++;
            }
        }
    };
    
    my @chromosomes = $regions->chromosomes;
    for my $chrom (@chromosomes) {
        my @regions = $regions->chromosome_regions($chrom);
        for my $region (@regions) {
            my $id = $region->name;
            my $target = $region->chrom;
            my $start = $region->start;
            my $end = $region->end;
            my $length = $region->length;
            
            # Here we get the $tid from the $gene_name or $seq_id
            my $tid = $target_name_index{$target};
            unless (defined $tid) { die('Failed to get tid for target '. $target); }
            
            # low-level API uses zero based coordinates
            # all regions should be zero based, but for some reason the correct length is never returned
            # the API must be expecting BED like inputs where the start is zero based and the end is 1-based
            # you can see in the docs for the low-level Bio::DB::BAM::Alignment class that start 'pos' is 0-based,but calend really returns 1-based
            my $coverage;
            if ($self->min_base_quality || $self->min_mapping_quality) {
                #Start with an empty array of zeros
                my @coverage = map { 0 } (1 .. $region->length);
                $coverage = \@coverage;
                # the pileup callback will add each base gt or eq to the quality_filter to the index position in the array ref
                $index->pileup($bam,$tid,$start-1,$end,$quality_coverage_callback,[$start-1,$end,$coverage])
            } else {
                $coverage = $index->coverage( $bam, $tid, $start-1, $end);
            }
            unless (scalar( @{ $coverage } ) == $region->length) {
                die('The length of locus '. $id .' '. $target.':'.$start .'-'. $end.'('.$length.') does not match the coverage array length '. scalar( @{ $coverage }));
            }
            for my $min_depth (@min_depths) {
                my $myCoverageStat = Genome::RefCov::Stats->create( coverage => $coverage , min_depth => $min_depth);
                print $stats_fh join ("\t", $id, @{ $myCoverageStat->stats() }) . "\n";
            }
        }
    }
    $stats_fh->close;

    Genome::Utility::FileSystem->copy_file($temp_stats_file, $self->stats_file);

    return 1;
}


1;
