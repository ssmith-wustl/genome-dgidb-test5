package Genome::Model::MetagenomicCompositionShotgun::Command::QcReport;

use strict;
use warnings;
use Genome;
use Genome::Model::InstrumentDataAssignment;
use File::Path;
use File::Find;

$|=1;

class Genome::Model::MetagenomicCompositionShotgun::Command::QcReport{
    is => 'Genome::Command::OO',
    doc => 'Generate QC report for a MetagenomicCompositionShotgun build.',
    has => [
        build_id => {
            is => 'Int',
        },
        base_output_dir => {
            is => 'Text',
        },
        overwrite => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
        },
        report_path => {
            is => 'Text',
            is_optional => 1,
        },
		log_path => {
			is => 'Text',
			is_optional => 1,
		},
    ],
};

sub execute {
    my ($self) = @_;

    my $build = Genome::Model::Build->get($self->build_id);
    my $model = $build->model;

    unless ($self->report_path){
        my $sample_name = $model->subject_name;
        my ($hmp, $patient, $site) = split(/-/, $sample_name);
        $patient = $hmp . '-' . $patient;
        my $build_id = $build->id;
        my $output_dir = $self->base_output_dir . "/" . $patient . "/" . $site . "/" . $build_id;
        mkpath $output_dir unless -d $output_dir;
        # TODO: check and warn if dir for different successful build id is present
        $self->report_path($output_dir);
    }
    unless ($self->log_path){
        $self->log_path($self->report_path . '/log');
    }
    $self->status_message("Report path: " . $self->report_path);


    my $dir = $build->data_directory;
    my ($contamination_bam, $contamination_flagstat, $meta1_bam, $meta1_flagstat, $meta2_bam, $meta2_flagstat) = map{ $dir ."/$_"}(
        "contamination_screen.bam",
        "contamination_screen.bam.flagstat",
        "metagenomic_alignment1.bam",
        "metagenomic_alignment1.bam.flagstat",
        "metagenomic_alignment2.bam",
        "metagenomic_alignment2.bam.flagstat",
    );

    my ($meta_model) = $model->_metagenomic_alignment_models;
    my @imported_data = map {$_->instrument_data} $meta_model->instrument_data_assignments;
    my @original_data = map {$_->instrument_data} $build->instrument_data_assignments;

    $DB::single = 1;
    # Get any existing metrics
    my @build_metrics = $build->metrics;
    my %metric;
    for my $build_metric (@build_metrics) {
        $metric{$build_metric->name} = $build_metric;
    }
    my $metric_name;

    # POST TRIMMING STATS
    # Pulled from the $contamination_bam including:
    #   number of quality trimmed bases per lane
    #   average length of quality trimmed reads per lane
    my $cs_stats_output_path = $self->report_path . '/post_trim_stats_report.tsv';
    #unless (-f $cs_stats_output_path && ! $self->overwrite) {
        $self->status_message("Generating post trimming stats...");
        unlink($cs_stats_output_path) if (-f $cs_stats_output_path);
        my $cs_stats_output = Genome::Utility::FileSystem->open_file_for_writing($cs_stats_output_path);

        my %cs_stats = $self->bam_stats_per_lane($contamination_bam);
        print $cs_stats_output "lane\taverage_read_length\ttotal_bases\ttotal_reads\n";
        for my $lane (keys %cs_stats) {
            print $cs_stats_output $lane . "\t" . $cs_stats{$lane}{average_length} . "\t" . $cs_stats{$lane}{total_bases} . "\t" . $cs_stats{$lane}{total_reads} . "\n";

            $metric_name = "$lane\_average_read_length";
            print "$metric_name\n";
            $metric{$metric_name}->delete() if($metric{$metric_name});
            unless(Genome::Model::Metric->create(build_id => $self->build_id, name => $metric_name, value => $cs_stats{$lane}{average_length})) {
                $self->error_message("Unable to create build metric (build_id=" . $self->build_id . ", $lane\_average_read_length)");
                die $self->error_message;
            }

            $metric_name = "$lane\_total_bases";
            print "$metric_name\n";
            $metric{$metric_name}->delete() if($metric{$metric_name});
            unless(Genome::Model::Metric->create(build_id => $self->build_id, name => $metric_name, value => $cs_stats{$lane}{total_bases})) {
                $self->error_message("Unable to create build metric (build_id=" . $self->build_id . ", $lane\_total_bases)");
                die $self->error_message;
            }
            
            $metric_name = "$lane\_total_reads";
            print "$metric_name\n";
            $metric{$metric_name}->delete() if($metric{$metric_name});
            unless(Genome::Model::Metric->create(build_id => $self->build_id, name => $metric_name, value => $cs_stats{$lane}{total_reads})) {
                $self->error_message("Unable to create build metric (build_id=" . $self->build_id . ", $lane\_total_reads)");
                die $self->error_message;
            }
        }
        #}
        #else {
        #$self->status_message("Skipping post trimming stats, use --overwrite to replace...");
        #}

    # COLLECTING UNTRIMMED SEQUENCES OF NON-HUMAN READS
    # count of unique, non-human bases per lane
    # human-filtered, untrimmed bam
    my $data_path = $self->report_path . '/data';
    mkpath($data_path);
    my @imported_fastq;
    my @original_fastq;
    my %fastq_files;

    $self->status_message("Extracting FastQ files from original and imported data...");
    for my $imported_data (@imported_data) {
        # determine original instrument data from imported data via alignment id in path
        (my $alignment_id = $imported_data->original_data_path) =~ s/.*\/([0-9]*)\/.*/$1/;
        my $alignment_data = Genome::InstrumentData::AlignmentResult->get($alignment_id)->instrument_data;
        my $original_data = Genome::InstrumentData::Solexa->get($alignment_data);
        my $imported_id = $imported_data->id;
        my $original_id = $original_data->id;

        my @imported_data_files;
        find(sub {push @imported_data_files, "$File::Find::name" if (/^$imported_id\D/)}, $data_path);
        my $already_extracted = scalar(@imported_data_files);
        if ($already_extracted && ! $self->overwrite) {
            $self->status_message("\tSkipping FastQ extraction for " . $imported_data->id . ", data already exists. Use --overwrite to replace...");
            next;
        }

        my $humanfree_bam_path = $self->report_path . '/data/' . $imported_id . '_humanfree_untrimmed.bam';
        my $original_bam_path = $self->report_path . '/data/' . $imported_id . '_original_untrimmed.bam';
        if (! $self->overwrite && -f $humanfree_bam_path && -f $original_bam_path) {
            $self->status_message("\t$imported_id: Skipping FastQ extraction for " . $imported_id . ", bam files already exists. Use --overwrite to replace...");
            next;
        }

        unlink(@imported_data_files);

        # untar both imported and original fastq files, only keeping paired files
        my @imported_fastq_filenames = $imported_data->dump_sanger_fastq_files;
        if (@imported_fastq_filenames == 2 ) {
            my @original_fastq_filenames = $original_data->dump_sanger_fastq_files;
            for my $file (@imported_fastq_filenames) {
                my $name = (split('/', $file))[-1];
                $name =~ s/\.txt$//;
                my $output_filename = $data_path . '/' . $name . '_imported_trimmed';
                Genome::Utility::FileSystem->copy_file($file, $output_filename);
                push @imported_fastq, $output_filename;
            }
            for my $file (@original_fastq_filenames) {
                my $name = (split('/', $file))[-1];
                $name =~ s/\.txt$//;
                my $output_filename = $data_path . '/' . $imported_id . '_' . $name . '_original';
                Genome::Utility::FileSystem->copy_file($file, $output_filename);
                push @original_fastq, $output_filename;
            }
        }
        else {
            $self->status_message("\tSkipping unpaired fastq...");
        }
    }
    for my $imported_data (@imported_data) {
        my $imported_id = $imported_data->id;
        my @imported_data_files;
        find(sub {push @imported_data_files, "$File::Find::name" if (/^$imported_id\D/)}, $data_path);
        my @trimmed_files = grep {/_imported_trimmed$/} @imported_data_files;
        my @original_files = grep {/_original$/} @imported_data_files;
        $fastq_files{$imported_id}{imported} = \@trimmed_files if (@trimmed_files > 0);
        $fastq_files{$imported_id}{original} = \@original_files if (@original_files > 0);
		# $self->status_message("ID: $imported_id");
		# $self->status_message("Original files: " . join(" -- ", @original_files));
		# $self->status_message("Trimmed files: " . join(" -- ", @trimmed_files));
    }

    # convert quality
    # nnutter: only convert imported or original as well?
    # nnutter: think we can skip this now with dump_sanger_fastq_files instead of fastq_filenames
#    $self->status_message("Converting quality of FastQ files...");
#    for my $id (keys %fastq_files) {
#        for my $fastq (@{$fastq_files{$id}{imported}}) {
#            unless (-f $fastq . '_qc' && ! $self->overwrite) {
#                $self->status_message("\tConverting: " . (split('/', $fastq))[-1] . "...");
#                Genome::Model::Tools::Fastq::Sol2phred->execute(fastq_file => $fastq);
#                rename($fastq . '.phred', $fastq . '_qc');
#            }
#            else {
#                $self->status_message("\tSkipping " . (split('/', $fastq))[-1] . "_qc file already exists...");
#            }
#            $fastq .= '_qc';
#        }
#    }

    $self->status_message("Generating human-free, untrimmed data...");
    for my $id (keys %fastq_files) {
        my $humanfree_fwd_path = $self->report_path . '/data/' . $id . '_1_humanfree_untrimmed';
        my $humanfree_rev_path = $self->report_path . '/data/' . $id . '_2_humanfree_untrimmed';
        if (! $self->overwrite && -f $humanfree_rev_path && -f $humanfree_fwd_path) {
            $self->status_message("\tSkipping $id, humanfree files already exists. Use --overwrite to replace...");
            next;
        }

        my $humanfree_bam_path = $self->report_path . '/data/' . $id . '_humanfree_untrimmed.bam';
        if (! $self->overwrite && -f $humanfree_bam_path) {
            $self->status_message("\t$id: Skipping humanfree creation, humanfree bam file already exists. Use --overwrite to replace...");
            next;
        }
        unlink($humanfree_fwd_path) if (-f $humanfree_fwd_path);
        unlink($humanfree_rev_path) if (-f $humanfree_rev_path);
        $self->status_message("\tGenerating hash of read names for instrument data: $id...");

        my $imported_path = (@{$fastq_files{$id}{imported}})[0];
        my $original_fwd_path = @{$fastq_files{$id}{original}}[0];
        my $original_rev_path = @{$fastq_files{$id}{original}}[1];
        my $imported_file = Genome::Utility::FileSystem->open_file_for_reading($imported_path);
        my $humanfree_fwd_file = Genome::Utility::FileSystem->open_file_for_writing($humanfree_fwd_path);
        my $humanfree_rev_file = Genome::Utility::FileSystem->open_file_for_writing($humanfree_rev_path);

        $self->status_message("\t\tReading in up to 8M read names...");
        my $reads_left = 1;
        my $readname_re = '[^:]*:(.*)#.*';
        while ($reads_left) {
            my %read_names;
            # read 12M reads at a time to prevent oom
            for (my $count = 0; $count < 8e6; $count++) {
                $self->status_message("\t\t\tHashed $count reads...") unless ($count % 2e6 || ! $count);
                my $imported_read = read_and_join_lines($imported_file);
                unless ($imported_read) {
                    $self->status_message("\t\t\tFinished reading $count reads.");
                    $reads_left = 0;
                    last;
                }
                $imported_read =~ /$readname_re/;
                my $imported_readname = $1;
                $read_names{$imported_readname} = 1;
            }

            my $original_fwd_file = Genome::Utility::FileSystem->open_file_for_reading($original_fwd_path);
            my $original_rev_file = Genome::Utility::FileSystem->open_file_for_reading($original_rev_path);

            $self->status_message("\t\tParsing original forward read file with those hashed reads...");
            while (my $fwd_read = read_and_join_lines($original_fwd_file)) {
                $fwd_read =~ /$readname_re/;
                my $fwd_readname = $1;
                if ($read_names{$fwd_readname}) {
                    print $humanfree_fwd_file $fwd_read ;
                }
            }

            $self->status_message("\t\tParsing original reverse read file with those hashed reads...");
            while (my $rev_read = read_and_join_lines($original_rev_file)) {
                $rev_read =~ /$readname_re/;
                my $rev_readname = $1;
                print $humanfree_rev_file $rev_read if ($read_names{$rev_readname});
            }
        }
    }

    # Write human-free, untrimmed bam
    $self->status_message("Creating bams...");
    for my $id (keys %fastq_files) {
        my $humanfree_fwd_path = $self->report_path . '/data/' . $id . '_1_humanfree_untrimmed';
        my $humanfree_rev_path = $self->report_path . '/data/' . $id . '_2_humanfree_untrimmed';
        my $humanfree_bam_path = $self->report_path . '/data/' . $id . '_humanfree_untrimmed.bam';
        my $original_bam_path = $self->report_path . '/data/' . $id . '_original_untrimmed.bam';
		my $original_fwd_path = @{$fastq_files{$id}{original}}[0];
		my $original_rev_path = @{$fastq_files{$id}{original}}[1];

        if (! $self->overwrite && -f $humanfree_bam_path && -f $original_bam_path) {
            $self->status_message("\t$id: Skipping humanfree/original bam creation, files already exists. Use --overwrite to replace...");
            next;
        }
        unlink([$humanfree_bam_path, $original_bam_path]);
        $self->status_message("\t$id: Generating humanfree/original bam files...");

        $self->status_message('\tVerifying fwd/rev pairs are correct, will swap if not...');

		# If original files are reversed then they probably just have rev in [0] and fwd in [1] so switch "pointer".
		my $original_fwd_file = Genome::Utility::FileSystem->open_file_for_reading($original_fwd_path);
        my $line = $original_fwd_file->getline;
        if ($line =~ /\/2$/) {
            $self->status_message("\t\t" . (split("/", $original_fwd_path))[-1] . " looks like a reverse file. Swapping...");
            my $tmp = @{$fastq_files{$id}{original}}[0];
            @{$fastq_files{$id}{original}}[0] = @{$fastq_files{$id}{original}}[1];
            @{$fastq_files{$id}{original}}[1] = $tmp;
			$original_fwd_path = @{$fastq_files{$id}{original}}[0];
			$original_rev_path = @{$fastq_files{$id}{original}}[1];
        }
		# If humanfree_untrimmed files are reversed then file contents are probably switched so switch files.
        my $humanfree_fwd_file = Genome::Utility::FileSystem->open_file_for_reading($humanfree_fwd_path);
        $line = $humanfree_fwd_file->getline;
        if ($line =~ /\/2$/) {
            $self->status_message("\t\t" . (split("/", $humanfree_fwd_path))[-1] . " looks like a reverse file. Swapping...");
            rename($humanfree_fwd_path, $humanfree_fwd_path . '.tmp');
            rename($humanfree_rev_path, $humanfree_fwd_path);
            rename($humanfree_fwd_path . '.tmp', $humanfree_rev_path);
        }

        my $idata = Genome::InstrumentData::Imported->get($id);
        $self->status_message("\t" . (split("/", $humanfree_bam_path))[-1]. "...");
        Genome::Model::Tools::Picard::FastqToSam->execute(
            fastq => $humanfree_fwd_path,
            fastq2 => $humanfree_rev_path,
            output => $humanfree_bam_path,
            quality_format => 'Standard',
            platform => 'illumina', # nnutter: Not sure what these are/should be?
            sample_name => $idata->sample_name,
            library_name => $idata->library_name,
            use_version => '1.21',
        );

        $self->status_message("\t" . (split("/", $original_bam_path))[-1]. "...");
        Genome::Model::Tools::Picard::FastqToSam->execute(
            fastq => $original_fwd_path,
            fastq2 => $original_rev_path,
            output => $original_bam_path,
            quality_format => 'Standard',
            platform => 'illumina', # nnutter: Not sure what these are/should be?
            sample_name => $idata->sample_name,
            library_name => $idata->library_name,
            use_version => '1.21',
        );
    }

    # Genome::Model::Tools::Picard::EstimateLibraryComplexity
    $self->status_message("Running Picard EstimateLibraryComplexity report...");
    for my $id (keys %fastq_files) {
        my $humanfree_bam_path = $self->report_path . '/data/' . $id . '_humanfree_untrimmed.bam';
        my $original_bam_path = $self->report_path . '/data/' . $id . '_original_untrimmed.bam';
        my $humanfree_report_path = $self->report_path . '/' . $id . '_humanfree_untrimmed_estimate_library_complexity_report.txt';
        my $original_report_path = $self->report_path . '/' . $id . '_original_untrimmed_estimate_library_complexity_report.txt';

        if (! $self->overwrite && -f $humanfree_report_path && -f $original_report_path) {
            $self->status_message("\t$id: Skipping EstimateLibraryComplexity, files already exists. Use --overwrite to replace...");
            next;
        }
        unlink([$humanfree_report_path, $original_report_path]);
        $self->status_message("\t$id: Generating EstimateLibraryComplexity report...");

        $self->status_message("\t\t" . (split("/", $original_report_path))[-1] . "...");
        Genome::Model::Tools::Picard::EstimateLibraryComplexity->execute(
            input_file => [$humanfree_bam_path],
            output_file => $humanfree_report_path,
            use_version => '1.21',
        );

        $self->status_message("\t\t" . (split("/", $original_report_path))[-1] . "...");
        Genome::Model::Tools::Picard::EstimateLibraryComplexity->execute(
            input_file => [$original_bam_path],
            output_file => $original_report_path,
            use_version => '1.21',
        );
    }

    # OTHER STATS
    # Pulled from the $contamination_flagstat including:
    #   the percent mapped
    #   duplicate count
    #   unique, non-human bases
    #   percent duplication of raw data
    my $other_stats_output_path = $self->report_path . '/other_stats_report.txt';
    #unless (-f $other_stats_output_path && ! $self->overwrite) {
        $self->status_message("Generating other stats...");
        unlink($other_stats_output_path) if (-f $other_stats_output_path);
        my $percent_mapped_to_contamination_ref;
        my $picard_mark_duplicates;
        my $cs_flagstat_file = Genome::Utility::FileSystem->open_file_for_reading($contamination_flagstat);
        while (<$cs_flagstat_file>) {
            $percent_mapped_to_contamination_ref = $1 if ($_ =~ /\d*\ mapped\ \(([^\)]*)/);
            $picard_mark_duplicates = $1 if ($_ =~ /(\d*)\ duplicates/);
        }

        my $other_stats_output= Genome::Utility::FileSystem->open_file_for_writing($other_stats_output_path);
        print $other_stats_output "Human Contamination Rate: $percent_mapped_to_contamination_ref\n";
        print $other_stats_output "Contamination Picard MarkDuplicates: $picard_mark_duplicates\n";

        $metric_name = "human_contamination_rate";
        $metric{$metric_name}->delete() if($metric{$metric_name});
        unless(Genome::Model::Metric->create(build_id => $self->build_id, name => $metric_name, value => $percent_mapped_to_contamination_ref)) {
            $self->error_message("Unable to create build metric (build_id=" . $self->build_id . ", human_contamination_rate)");
            die $self->error_message;
        }

        $metric_name = "contamination_picard_mark_duplicates";
        $metric{$metric_name}->delete() if($metric{$metric_name});
        unless(Genome::Model::Metric->create(build_id => $self->build_id, name => $metric_name, value => $picard_mark_duplicates)) {
            $self->error_message("Unable to create build metric (build_id=" . $self->build_id . ", contamination_picard_mark_duplicates)");
            die $self->error_message;
        }

        for my $id (keys %fastq_files) {
            my $humanfree_report_path = $self->report_path . '/' . $id . '_humanfree_untrimmed_estimate_library_complexity_report.txt';
            my $original_report_path = $self->report_path . '/' . $id . '_original_untrimmed_estimate_library_complexity_report.txt';
            my $humanfree_report_fh = Genome::Utility::FileSystem->open_file_for_reading($humanfree_report_path);
            my $original_report_fh = Genome::Utility::FileSystem->open_file_for_reading($original_report_path);
            while (<$humanfree_report_fh>) {
                if (/^##\ HISTOGRAM/) {
                    my $line = $humanfree_report_fh->getline();
                    my $unique_bases_count = 0;
                    while (<$humanfree_report_fh>) {
                        $line = $_;
                        my $count = (split("\t", $line))[1];
                        $unique_bases_count += $count if $count;
                    }
                    print $other_stats_output "$id: Unique, non-human bases: $unique_bases_count\n";

                    $metric_name = "unique_humanfree_bases_$id";
                    print "$metric_name\n";
                    $metric{$metric_name}->delete() if($metric{$metric_name});
                    unless(Genome::Model::Metric->create(build_id => $self->build_id, name => $metric_name, value => $unique_bases_count)) {
                        $self->error_message("Unable to create build metric (build_id=" . $self->build_id . ", unique_humanfree_bases_$id)");
                        die $self->error_message;
                    }
                }
            }
            while (<$original_report_fh>) {
                if (/^##\ METRICS/) {
                    my $keys = $original_report_fh->getline();
                    my $values = $original_report_fh->getline();
                    my @keys = split("\t", lc($keys));
                    my @values = split("\t", $values);
                    my %metrics;
                    @metrics{@keys} = @values;
                    print $other_stats_output "$id: Percent Duplication: " . $metrics{percent_duplication} . "\n";

                    $metric_name = "percent_duplication_$id";
                    print "$metric_name\n";
                    $metric{$metric_name}->delete() if($metric{$metric_name});
                    unless(Genome::Model::Metric->create(build_id => $self->build_id, name => $metric_name, value => $metrics{percent_duplication})) {
                        $self->error_message("Unable to create build metric (build_id=" . $self->build_id . ", percent_duplication_$id)");
                        die $self->error_message;
                    }
                }
            }

        }
#    }
#    else {
#        $self->status_message("Skipping other stats, use --overwrite to replace...");
#    }

    $self->status_message("Removing unneeded FastQ files...");
    for my $id (keys %fastq_files) {
        unlink(@{$fastq_files{$id}{original}}[0]) if (-f @{$fastq_files{$id}{original}}[0]);
        unlink(@{$fastq_files{$id}{original}}[1]) if (-f @{$fastq_files{$id}{original}}[1]);
        unlink(@{$fastq_files{$id}{imported}}[0]) if (-f @{$fastq_files{$id}{imported}}[0]);
        unlink(@{$fastq_files{$id}{imported}}[1]) if (-f @{$fastq_files{$id}{imported}}[1]);

        my $humanfree_fwd_path = $self->report_path . '/data/' . $id . '_1_humanfree_untrimmed';
        my $humanfree_rev_path = $self->report_path . '/data/' . $id . '_2_humanfree_untrimmed';
        unlink($humanfree_fwd_path) if (-f $humanfree_fwd_path);
        unlink($humanfree_rev_path) if (-f $humanfree_rev_path);
    }


    print "\n\n";
    $self->status_message('Model: ' . $model->name);
    $self->status_message('Build: ' . $build->id);
    $self->status_message('Reports: ' . $self->report_path);
    $self->status_message('Report Data: ' . $self->report_path . '/data');
    my $done = system("touch ".$self->report_path."/FINISHED");
    return 1;
}

sub read_and_join_lines {
    my ($fh, $num) = @_;
    $num = 4 unless ($num);

    my @lines;
    for (my $count = 0; $count < 4; $count++) {
        my $line = $fh->getline;
        return undef unless $line;
        push @lines, $line;
    }
    return join('', @lines);
}

sub sort_bams_by_name {
    my $self = shift;
    my @bams = @_;
    my @sorted_bams;
    my $sorted_output_dir = $self->base_output_dir . '/bams';
    mkpath($sorted_output_dir) unless -d $sorted_output_dir;
    for my $bam (@bams) {
        my $sorted_bam = (split('/', $bam))[-1];
        $sorted_bam =~ s/\.bam$//; # strip off .bam because samtools adds it
        $sorted_bam = $sorted_output_dir . '/' . $sorted_bam . '_name_sorted';

        Genome::Model::Tools::Sam::SortBam->execute(
            file_name => $bam,
            name_sort => 1,
            output_file => $sorted_bam,
            maximum_memory => 1250000000,
        );
        push @sorted_bams, $sorted_bam . '.bam';
    }
    return @sorted_bams;
}

sub merge_bams {
    my $self = shift;
    my $output_file = shift;
    my @input_files = @_;
    my $rv = Genome::Model::Tools::Sam::MergeSplitReferenceAlignments->execute(
        input_files => \@input_files,
        input_format => 'BAM',
        output_file => $output_file,
        output_format => 'BAM',
    );
    unless ($rv){
        $self->error_message("Failed to sort and merge bams");
        die;
    }
}

sub sort_fastq {
    my $file = shift;
    my $file_fh = IO::File->new($file);
    my $sort_fh = IO::File->new(' | sort -z -n | tr -d \'\000\' > ' . $file . '_sorted');

    my @records;
    my @record_lines;
    my $count = 1;
    while (<$file_fh>) {
        push @record_lines, $_;
        unless ($count % 4) {
            push @records, join('', @record_lines) . "\0";
            print $sort_fh join('', @record_lines) . "\0";
            @record_lines = ();
        }
        $count++;
    }
}

sub bam_stats_per_lane {
    my $self = shift;
    my $bam = shift;
    my $bam_fh = IO::File->new("samtools view $bam |");
    unless($bam_fh) {
        $self->error_message("Failed to open $bam for reading.");
        die $self->error_message;
    }

    my %stats;
    while (<$bam_fh>){
        my @fields = split("\t", $_);
        my $seq = $fields[9];
        (my $solexa_id = $fields[11]) =~ s/.*://;
        my $lane = Genome::InstrumentData::Solexa->get($solexa_id)->flow_cell_id;
        $lane .= '-' . Genome::InstrumentData::Solexa->get($solexa_id)->lane;
        if ($seq eq '*'){
            $self->status_message("invalid sequence for read in bam: $_");
            next;
        }else{
            $stats{$lane}{total_bases} += length($seq);
        }
        $stats{$lane}{total_reads}++;
    }
    for my $lane (keys %stats) {
        $stats{$lane}{average_length} = $stats{$lane}{total_bases}/$stats{$lane}{total_reads};
    }
    return %stats;
}

1;

