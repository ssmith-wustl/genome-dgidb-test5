package Genome::Model::Tools::RefCov;

use strict;
use warnings;

use Genome;

my @GC_HEADERS = qw/
                       gc_reflen_bp
                       gc_reflen_percent
                       gc_covlen_bp
                       gc_covlen_percent
                       gc_uncovlen_bp
                       gc_uncovlen_percent
                   /;

#Possibly replace with subroutine/CODEREF?
my %MERGE_STATS_OPERATION = (
    name => undef,
    percent_ref_bases_covered => undef,
    total_ref_bases => '+',
    total_covered_bases => '+',
    missing_bases => '+',
    ave_cov_depth => '* total_covered_bases',
    sdev_ave_cov_depth => 'weighted_mean',
    med_cov_depth => 'weighted_mean',
    gap_number => '+',
    ave_gap_length => '* gap_number',
    sdev_ave_gap_length => 'weighted_mean',
    med_gap_length => 'weighted_mean',
    min_depth_filter => 'min_depth_filter',
    min_depth_discarded_bases => '+',
    percent_min_depth_discarded => undef,
    gc_reflen_bp => '+',
    gc_reflen_percent => undef,
    gc_covlen_bp => '+',
    gc_covlen_percent => undef,
    gc_uncovlen_bp => '+',
    gc_uncovlen_percent => undef,
    roi_normalized_depth => 'weighted_mean',
    genome_normalized_depth => 'weighted_mean',
    intervals => 'intervals',
);

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
        reference_fasta => {
            is => 'String',
            doc => 'The path to the reference genome fasta file',
            is_optional => 1,
        },
        output_directory => {
            doc => 'When run in parallel, this directory will contain all output and intermediate STATS files. Sub-directories will be made for wingspan and min_depth_filter params. Do not define if stats_file is defined.',
            is_optional => 1,
        },
        print_headers => {
            is => 'Boolean',
            doc => 'Print a header describing the output including column headers.',
            is_optional => 1,
            default_value => 0,
        },
        merged_stats_file => {
            is => 'Text',
            doc => 'The final merged stats file only created if merge_by parameter defined',
            is_optional => 1,
        },
        merge_by => {
            is => 'Text',
            doc => 'The level of granularity to merge coverage statistics.  Requires ROI file uses interval names like $GENE:$TRANSCRIPT:$TYPE:$ORDINAL:$DIRECTION',
            is_optional => 1,
            valid_values => ['exome','gene','transcript'],
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
        _fai => {},
        _roi_stats => {},
        _genome_stats => {},
        _nuc_cov => {},
        _roi_cov => {},
    ],
};

sub help_brief {
    "Tools to run the RefCov tookit.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt ref-cov ...
EOS
}

sub help_detail {
'
Output file format(STANDARD):
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

OPTIONAL GC FIELDS:
[1] G+C Reference Base Pair
[2] G+C Percent of Reference
[3] G+C Covered Base Pair
[4] G+C Percent of Reference Covered
[5] G+C Uncovered Base Pair
[6] G+C Percent of Reference Uncovered

OPTIONAL ROI NORMALIZED COVERAGE FIELD:
[1] ROI Normalized Depth

OPTIONAL GENOME NORMALIZED COVERAGE FIELD:
[1] Genome Normalized Depth
';
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    unless ($self) { return; }

    unless ($] > 5.012) {
        die "Bio::DB::Sam requires perl 5.12!";
    }
    require Bio::DB::Sam;

    if ($self->evaluate_gc_content) {
        unless ($self->reference_fasta) {
            die('In order to evaluate_gc_content a FASTA file of the reference genome must be provided');
        }
    }
    if ($self->merge_by) {
        unless ($self->merged_stats_file) {
            die('Please define a merged_stats_file in order to merge by '. $self->merge_by);
        }
    }
    # This is only necessary when run in parallel
    $self->resolve_final_directory;
    $self->resolve_stats_file;
    return $self;
}


# NOTE: I doubt we ever support anything but BAM.  If we do, some common adaptor/iterator will be necessary to do something like $alignments->next_alignment
sub _load_alignments {
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

sub alignments {
    my $self = shift;
    unless ($self->_alignments) {
        $self->_load_alignments;
    }
    return $self->_alignments;
}

sub _load_roi {
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

sub roi {
    my $self = shift;
    unless ($self->_roi) {
        $self->_load_roi;
    }
    return $self->_roi;
}

sub nucleotide_coverage {
    my $self = shift;
    unless ($self->_nuc_cov) {
        my $gc = Genome::RefCov::Reference::GC->create();
        $self->_nuc_cov($gc);
    }
    return $self->_nuc_cov;
}

sub region_coverage_stat {
    my $self = shift;
    unless ($self->_roi_cov) {
        my $stat = Genome::RefCov::Stats->create();
        $self->_roi_cov($stat);
    }
    return $self->_roi_cov;
}

sub _load_fai {
    my $self = shift;
    my $fasta_file = $self->reference_fasta;
    unless ($fasta_file) { return; }
    unless (-f $fasta_file .'.fai') {
        # TODO: We chould try to create the fasta index
        die('Failed to find fai index for fasta file '. $fasta_file);
    }
    my $fai = Bio::DB::Sam::Fai->load($fasta_file);
    unless ($fai) {
        die('Failed to load fai index for fasta file '. $fasta_file);
    }
    $self->_fai($fai);
    return $fai;
}

sub fai {
    my $self = shift;
    unless ($self->_fai) {
        $self->_load_fai;
    }
    return $self->_fai;
}

sub _load_roi_stats {
    my $self = shift;
    my $alignments = $self->alignments;
    $self->status_message('Loading ROI Reference Stats...');
    my $roi_stats = Genome::RefCov::Reference::Stats->create(
        bam => $alignments->bio_db_bam,
        bam_index => $alignments->bio_db_index,
        bed_file => $self->roi_file_path,
    );
    $self->_roi_stats($roi_stats);
    $self->status_message('Finished loading ROI Reference Stats!');
    return $roi_stats;
}

sub roi_stats {
    my $self = shift;
    unless ($self->_roi_stats) {
        $self->_load_roi_stats;
    }
    return $self->_roi_stats;
}

sub _load_genome_stats {
    my $self = shift;
    my $alignments = $self->alignments;
    $self->status_message('Loading Genome Reference Stats...');
    my $genome_stats = Genome::RefCov::Reference::Stats->create(
        bam => $alignments->bio_db_bam,
        bam_index => $alignments->bio_db_index,
    );
    $self->_genome_stats($genome_stats);
    $self->status_message('Finished loading Genome Reference Stats!');
    return $genome_stats;
}

sub genome_stats {
    my $self = shift;
    unless ($self->_genome_stats) {
        $self->_load_genome_stats;
    }
    return $self->_genome_stats;
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
            unless (Genome::Sys->create_directory($output_directory)) {
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
        my ($alignment_basename,$alignment_dirname,$alignment_suffix) = File::Basename::fileparse($self->alignment_file_path,($alignment_file_expected_suffix));
        unless ($alignment_suffix) {
            die('Failed to recognize file '. $self->alignment_file_path .' without expected suffix '. $alignment_file_expected_suffix);
        }
        my $roi_file_expected_suffix = '.'. $self->roi_file_format;
        my ($regions_basename,$roi_dirname,$roi_suffix) = File::Basename::fileparse($self->roi_file_path,($roi_file_expected_suffix));
        unless ($roi_suffix) {
            die('Failed to recognize file '. $self->roi_file_path .' without bed suffix');
        }
        $self->stats_file($self->final_directory .'/'. $alignment_basename .'_'. $regions_basename .'_STATS.tsv');
    }
    return 1;
}

sub region_sequence_array_ref {
    my $self = shift;
    my $region = shift;

    my $fai = $self->fai;
    my $id = $region->{id};
    #$self->status_message('Fetching sequence for region '. $id);
    my $dna_string = $fai->fetch($id);
    my @dna = split('',$dna_string);
    unless (scalar(@dna) == $region->{length}) {
        die('Failed to fetch the proper length ('. $region->{length} .') dna.  Fetched '. scalar(@dna) .' bases!');
    }
    return \@dna;
}

sub region_coverage_array_ref {
    my $self = shift;
    my $region = shift;

    my $alignments = $self->alignments;
    my $bam = $alignments->bio_db_bam;
    my $index = $alignments->bio_db_index;
    my $tid = $alignments->tid_for_chr($region->{chrom});
    #$self->status_message('Fetching coverage for region '. $region->{id});
    my $coverage;
    if ($self->min_base_quality || $self->min_mapping_quality) {
        $coverage = $self->region_coverage_with_quality_filter($region);
    } else {
        # low-level API uses zero based coordinates
        # all regions should be zero based, but for some reason the correct length is never returned
        # the API must be expecting BED like inputs where the start is zero based and the end is 1-based
        # you can see in the docs for the low-level Bio::DB::BAM::Alignment class that start 'pos' is 0-based,but calend really returns 1-based
        $coverage = $index->coverage( $bam, $tid, ($region->{start} - 1), $region->{end});
    }
    unless (scalar( @{ $coverage } ) == $region->{length}) {
        die('The length of region '. $region->{name} .' '. $region->{id}
                .'('. $region->{length} .') does not match the coverage array length '. scalar( @{ $coverage }));
    }
    return $coverage;
}

sub region_coverage_with_quality_filter {
    my $self = shift;
    my $region = shift;

    my $alignments = $self->alignments;
    my $bam = $alignments->bio_db_bam;
    my $index = $alignments->bio_db_index;
    my $tid = $alignments->tid_for_chr($region->{chrom});

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
    my @coverage = map { 0 } (1 .. $region->{length});
    my $coverage = \@coverage;
    # the pileup callback will add each base gt or eq to the quality_filter to the index position in the array ref
    $index->pileup($bam,$tid,($region->{start} - 1),$region->{end},$quality_coverage_callback,[($region->{start} - 1),$region->{end},$coverage]);
    return $coverage;
}

#sub resolve_stats_class {
#    my $self = shift;
#    #TODO: this is suboptimal there is a better way to do this through delegation, inheritance, factory... something
#    if ($self->evaluate_gc_content) {
#        if ($self->roi_normalized_coverage) {
#            return Genome::RefCov::ExomeCaptureStats;
#        }
#        if ($self->genome_normalized_coverage) {
#            return Genome::RefCov::WholeGenomeStats;
#        }
#    } else {
#        if (!$self->roi_normalized_coverage && !$self->genome_normalized_coverage) {
#            return Genome::RefCov::Stats;
#        }
#    }
#    die('No class implemented for combination of parameters!');
#}

sub merge_stats_by {
    my $self = shift;
    my $merge_by = shift;
    my $file = shift;

    unless (defined($merge_by)) {
        die('Must provide a merge_by option!');
    }

    # **NOTE**
    # Operation should be performed post print_standard_roi_coverage()
    # execution.
    my %params = (
        input   => $self->stats_file,
        separator => "\t",
    );
    my @headers;
    unless ($self->print_headers){
        @headers = $self->resolve_stats_file_headers;
        $params{headers} = \@headers;
    }
    my $stats_reader = Genome::Utility::IO::SeparatedValueReader->new(%params);
    unless (@headers) {
        @headers = @{$stats_reader->headers};
    }
    my %merge_by_stats;
    while (my $data = $stats_reader->next) {
        my $name = $data->{name};
        unless ($name) {
            die('Failed to find name for stats region: '. Data::Dumper::Dumper($data));
        }
        my ($gene,$transcript,$type,$ordinal,$strand) = split(':',$name);
        unless ($gene && $transcript && $type) {
            die('Failed to parse ROI name:  '. $name);
        }
        my $merge_key = $merge_by;
        if ($merge_by eq 'gene') {
            $merge_key = $gene;
        } elsif ($merge_by eq 'transcript') {
            $merge_key = $transcript;
        } elsif ($merge_by eq 'exon') {
            die('The ROI should be at the exon level.  Why would it not?');
            $merge_key = $gene .':'. $transcript .':'. $type;
            if (defined $ordinal) {
                $merge_key .= ':' . $ordinal;
            }
        }
        $merge_by_stats{$merge_key}{intervals}++;
        for my $data_key (keys %{$data}) {
            if ($data_key eq 'name') {
                next;
            }
            my $data_value = $data->{$data_key};
            my $operation = $MERGE_STATS_OPERATION{$data_key};
            if (defined($operation)) {
                if ($operation eq '+') {
                    $merge_by_stats{$merge_key}{$data_key} += $data_value;
                } elsif ($operation =~ /^\*\s+(\S+)/) {
                    my $multiplier_key = $1;
                    my $multiplier_value = $data->{$multiplier_key};
                    $merge_by_stats{$merge_key}{$data_key} += ($data_value * $multiplier_value);
                } elsif ($operation eq 'weighted_mean') {
                    $merge_by_stats{$merge_key}{$data_key} += ($data_value * $data->{total_ref_bases});
                } elsif ($operation) {
                    $merge_by_stats{$merge_key}{$data_key} = $data_value;
                }
            }
        }
    }
    my $writer = Genome::Utility::IO::SeparatedValueWriter->new(
        output => $file,
        separator => "\t",
        headers => \@headers,
    );
    for my $merge_key (keys %merge_by_stats) {
        my %data;
        my $length = $merge_by_stats{$merge_key}{total_ref_bases};
        my $covered = $merge_by_stats{$merge_key}{total_covered_bases};
        my $uncovered = $merge_by_stats{$merge_key}{missing_bases};
        for my $header (@headers) {
            if (defined $merge_by_stats{$merge_key}{$header}) {
                my $data_value = $merge_by_stats{$merge_key}{$header};
                my $operation = $MERGE_STATS_OPERATION{$header};
                if ($operation =~ /^\+$/) {
                    $data{$header} = $data_value;
                } elsif ($operation =~ /^\*\s+(\S+)/) {
                    my $multiplier_key = $1;
                    my $multiplier_value = $merge_by_stats{$merge_key}{$multiplier_key};
                    if ($multiplier_value) {
                        $data{$header} = $self->_round(($data_value / $multiplier_value));
                    } elsif ($data_value) {
                        $self->error_message('For header '. $header .' found value '. $data_value .' but no denominator '. $multiplier_value);
                        die($self->error_message);
                    } else {
                        $data{$header} = 0;
                    }
                } elsif ($operation eq 'weighted_mean') {
                    $data{$header} = $self->_round(($data_value / $length));
                } elsif ($operation) {
                    $data{$header} = $data_value;
                } else {
                    die('Not sure what to do with '. $header);
                }
            } elsif ($header =~ /^gc_(\S+)_percent$/) {
                my $type = $1;
                my $method = 'gc_'. $type .'_bp';
                if ($type eq 'reflen') {
                    $data{$header} = $self->_round((($merge_by_stats{$merge_key}{$method} / $length )* 100));
                } elsif ($type eq 'covlen') {
                    if ($covered) {
                        $data{$header} = $self->_round((($merge_by_stats{$merge_key}{$method} / $covered )* 100));
                    } else {
                        $data{$header} = 0;
                    }
                } elsif ($type eq 'uncovlen') {
                    if ($uncovered) {
                        $data{$header} = $self->_round((($merge_by_stats{$merge_key}{$method} / $uncovered )* 100));
                    } else {
                        $data{$header} = 0;
                    }
                }
            } elsif ($header eq 'percent_min_depth_discarded') {
                $data{$header} = $self->_round((($merge_by_stats{$merge_key}{'min_depth_discarded_bases'} / $merge_by_stats{$merge_key}{total_ref_bases}) * 100));
            } elsif ($header eq 'percent_ref_bases_covered') {
                $data{$header} = $self->_round( ( ($covered / $length) * 100 ) );
            } elsif ($header eq 'name') {
                $data{$header} = $merge_key;
            } else {
                die('Please implement condition to deal with header: '. $header);
            }
        }
        unless ($writer->write_one(\%data)) {
            die($writer->error_message);
        }
    }
    $writer->output->close;

    return 1;
}

sub resolve_stats_file_headers {
    my $self = shift;
    my @headers = Genome::RefCov::Stats->headers;
    if ($self->evaluate_gc_content) {
        push @headers, $self->gc_headers;
    }
    if ($self->roi_normalized_coverage) {
        push @headers, 'roi_normalized_depth';
    }
    if ($self->genome_normalized_coverage) {
        push @headers, 'genome_normalized_depth';
    }
    return @headers;
}

sub validate_chromosomes {
    my $self = shift;
    my $roi = $self->roi;
    my $refcov_bam = $self->alignments;
    for my $chr ($roi->chromosomes) {
        eval {
            my $tid = $refcov_bam->tid_for_chr($chr);
        };
        if ($@) {
            die('Failed to validate chromsomes in ROI '. $self->roi_file_format .' file '. $self->roi_file_path .' with alignment '. $self->alignment_file_format .' file '. $self->alignment_file_path .' with error:' ."\n". $@);
        }
    }
    return 1;
}

sub print_roi_coverage {
    my $self = shift;

    $self->validate_chromosomes;

    my $temp_stats_file = Genome::Sys->create_temp_file_path;
    my @headers = $self->resolve_stats_file_headers;
    my $writer = Genome::Utility::IO::SeparatedValueWriter->create(
        separator => "\t",
        headers => \@headers,
        output => $temp_stats_file,
        print_headers => $self->print_headers,
    );
    unless ($writer) {
        die 'Failed to open stats file for writing '. $temp_stats_file;
    }
    my $roi = $self->roi;
    my $stat = $self->region_coverage_stat;
    my @min_depths = split(',',$self->min_depth_filter);
    while (my $region = $roi->next_region) {
        my $coverage_array_ref = $self->region_coverage_array_ref($region);
        my $sequence_array_ref;
        if ($self->evaluate_gc_content) {
            $sequence_array_ref = $self->region_sequence_array_ref($region);
        }
        for my $min_depth (@min_depths) {
            $stat->calculate_coverage_stats(
                coverage => $coverage_array_ref,
                min_depth => $min_depth,
                name => $region->{name},
            );
            my $data = $stat->stats_hash_ref;
            if ($self->evaluate_gc_content) {
                #$self->status_message('Evaluating GC content of '. $data->{name} .' '. $region->{id});
                my $gc_data = $self->evaluate_region_gc_content($sequence_array_ref,$coverage_array_ref);
                for my $key (keys %{$gc_data}) {
                    $data->{$key} = $gc_data->{$key};
                }
            }
            if ($self->roi_normalized_coverage) {
                my $roi_stats = $self->roi_stats;
                my $roi_normalized_depth = $self->_round( ($stat->ave_cov_depth / $roi_stats->mean_coverage) );
                $data->{'roi_normalized_depth'} = $roi_normalized_depth;
            }
            if ($self->genome_normalized_coverage) {
                my $genome_stats = $self->genome_stats;
                my $genome_normalized_depth = $self->_round( ($stat->ave_cov_depth / $genome_stats->mean_coverage) );
                $data->{'genome_normalized_depth'} = $genome_normalized_depth;
            }
            unless ($writer->write_one($data)) {
                die($writer->error_message);
            }
        }
    }
    $writer->output->close;

    Genome::Sys->copy_file($temp_stats_file, $self->stats_file);
    if ($self->merge_by && $self->merged_stats_file) {
        $self->merge_stats_by($self->merge_by,$self->merged_stats_file);
    }
    return 1;
}


sub evaluate_region_gc_content {
    my $self = shift;
    my $sequence = shift;
    my $coverage = shift;

    #$self->status_message('Loading GC Reference Coverage...');
    my $nucleotide_coverage = $self->nucleotide_coverage;
    $nucleotide_coverage->calculate_nucleotide_coverage(
        sequence => $sequence,
        coverage => $coverage,
    );
    unless ($nucleotide_coverage) {
        die('Failed to create GC coverage!');
    }
    #$self->status_message('Finished loading GC Reference Coverage...');
    my $gc_hash_ref = $nucleotide_coverage->gc_hash_ref;
    return $gc_hash_ref;
}

sub gc_headers {
    return @GC_HEADERS;
}

sub _round {
    my $self = shift;
    my $value = shift;
    return sprintf( "%.2f", $value );
}

1;
