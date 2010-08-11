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
        overwrite => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
        },
        report_dir => {
            is => 'Text',
            is_optional => 1,
        },
    ],
};

sub execute {
    my ($self) = @_;

    my $build = Genome::Model::Build->get($self->build_id);
    my $model = $build->model;

    unless ($self->report_dir){
        $self->report_dir($build->data_directory . "/reports");
    }
    mkpath $self->report_dir unless (-d $self->report_dir);
    $self->status_message("Report path: " . $self->report_dir);


    my $dir = $build->data_directory;
    my ($contamination_bam, $contamination_flagstat, $meta1_bam, $meta1_flagstat, $meta2_bam, $meta2_flagstat) = map{ $dir ."/$_"}(
        "contamination_screen.bam",
        "contamination_screen.bam.flagstat",
        "metagenomic_alignment1.bam",
        "metagenomic_alignment1.bam.flagstat",
        "metagenomic_alignment2.bam",
        "metagenomic_alignment2.bam.flagstat",
    );

    my $temp_dir = Genome::Utility::FileSystem->base_temp_directory;

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
    my $stats_output_path = $self->report_dir . '/post_trim_stats_report.tsv';
        $self->status_message("Generating post trimming stats...");
        unlink($stats_output_path) if (-f $stats_output_path);
        my $stats_output = Genome::Utility::FileSystem->open_file_for_writing($stats_output_path);

        $self->status_message("\tParsing $contamination_bam...");
        my %stats = $self->bam_stats_per_lane($contamination_bam);
        $self->status_message("\tParsing of $contamination_bam is complete.");

        # print header
        print $stats_output "flow_lane";
        my $flow_lane = (keys(%stats))[0];
        for my $stat (sort(keys %{$stats{$flow_lane}})) {
            print $stats_output "\t$stat";
        }
        print $stats_output "\n";

        for my $flow_lane (sort(keys %stats)) {
            # print values
            print $stats_output $flow_lane;
            for my $stat (sort(keys %{$stats{$flow_lane}})) {
                $metric_name = $flow_lane . "_" . $stat;
                $metric{$metric_name}->delete() if($metric{$metric_name});
                unless(Genome::Model::Metric->create(build_id => $self->build_id, name => $metric_name, value => $stats{$flow_lane}{$stat})) {
                    $self->error_message("Unable to create build metric (build_id=" . $self->build_id . ", $metric_name)");
                    die $self->error_message;
                }
                print $stats_output "\t" . $stats{$flow_lane}{$stat};
            }
            print $stats_output "\n";
        }

        # COLLECTING UNTRIMMED SEQUENCES OF NON-HUMAN READS
        # count of unique, non-human bases per lane
        # human-filtered, untrimmed bam
        my $data_path = $self->report_dir . '/data';
        mkpath($data_path);
        my @imported_fastq;
        my @original_fastq;
        my %fastq_files;

        $self->status_message("Extracting FastQ files from original and imported data...");
        for my $imported_data (@imported_data) {
            my $imported_id = $imported_data->id;
            my $original_data = $self->original_data_from_imported_id($imported_id);

            my $humanfree_bam_path = $self->report_dir . '/data/' . $imported_id . '_humanfree_untrimmed.bam';
            my $original_bam_path = $self->report_dir . '/data/' . $imported_id . '_original_untrimmed.bam';
            if (! $self->overwrite && -f $humanfree_bam_path && -f $original_bam_path) {
                $self->status_message("\t$imported_id: Skipping FastQ extraction for " . $imported_id . ", bam files already exists. Use --overwrite to replace...");
                next;
            }

            # untar both imported and original fastq files, only keeping paired files
            my @imported_fastq_filenames = $imported_data->dump_sanger_fastq_files;
            if (@imported_fastq_filenames == 2 ) {
                my @original_fastq_filenames = $original_data->dump_sanger_fastq_files;
                for my $file (@imported_fastq_filenames) {
                    my $name = (split('/', $file))[-1];
                    $name =~ s/\.txt$//;
                    my $output_filename = $temp_dir . '/' . $name . '_imported_trimmed';
                    Genome::Utility::FileSystem->copy_file($file, $output_filename);
                    push @imported_fastq, $output_filename;
                }
                for my $file (@original_fastq_filenames) {
                    my $name = (split('/', $file))[-1];
                    $name =~ s/\.txt$//;
                    my $output_filename = $temp_dir . '/' . $imported_id . '_' . $name . '_original';
                    Genome::Utility::FileSystem->copy_file($file, $output_filename);
                    push @original_fastq, $output_filename;
                }
            }
            else {
                $self->status_message("\tSkipping unpaired fastq...");
            }
        }

        my %imported_data_ids;
        for my $imported_data (@imported_data) {
            my $imported_id = $imported_data->id;
            my @imported_data_files;
            find(sub {push @imported_data_files, "$File::Find::name" if (/^$imported_id\D/)}, $data_path);
            if (@imported_data_files) {
                $imported_data_ids{$imported_id} = 1;
            }
            my @trimmed_files = grep {/_imported_trimmed$/} @imported_data_files;
            my @original_files = grep {/_original$/} @imported_data_files;
            $fastq_files{$imported_id}{imported} = \@trimmed_files if (@trimmed_files > 0);
            $fastq_files{$imported_id}{original} = \@original_files if (@original_files > 0);

        }
        my @imported_data_ids = keys(%imported_data_ids);

        $self->status_message("Generating human-free, untrimmed data...");
        for my $id (@imported_data_ids) {
            my $humanfree_bam_path = $self->report_dir . '/data/' . $id . '_humanfree_untrimmed.bam';
            if (! $self->overwrite && -f $humanfree_bam_path) {
                $self->status_message("\t$id: Skipping humanfree creation, humanfree bam file already exists. Use --overwrite to replace...");
                next;
            }

            my $humanfree_fwd_path = $temp_dir . '/' . $id . '_1_humanfree_untrimmed';
            my $humanfree_rev_path = $temp_dir . '/' . $id . '_2_humanfree_untrimmed';

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
                    if ($read_names{$rev_readname}) {
                        print $humanfree_rev_file $rev_read ;
                    }
                }
            }
        }

        # Write human-free, untrimmed bam
        $self->status_message("Creating bams...");
        for my $id (@imported_data_ids) {
            my $humanfree_fwd_path = $temp_dir . '/' . $id . '_1_humanfree_untrimmed';
            my $humanfree_rev_path = $temp_dir . '/' . $id . '_2_humanfree_untrimmed';
            my $humanfree_bam_path = $self->report_dir . '/data/' . $id . '_humanfree_untrimmed.bam';
            my $original_bam_path = $self->report_dir . '/data/' . $id . '_original_untrimmed.bam';
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

        # Count bases in humanfree, untrimmed bams
        $self->status_message("Counting human-free, untrimmed bases per lane...");
        my %humanfree_base_count;
        for my $id (@imported_data_ids) {
            my $humanfree_bam_path = $self->report_dir . '/data/' . $id . '_humanfree_untrimmed.bam';

            $self->expect64();
            my $bam_fh = IO::File->new("samtools view $humanfree_bam_path |");
            while (<$bam_fh>) {
                my $read = $_;
                my $bases = (split("\t", $read))[9];
                $humanfree_base_count{$id} += length($bases);
            }
        }


        # Genome::Model::Tools::Picard::EstimateLibraryComplexity
        $self->status_message("Running Picard EstimateLibraryComplexity report...");
        for my $id (@imported_data_ids) {
            my $humanfree_bam_path = $self->report_dir . '/data/' . $id . '_humanfree_untrimmed.bam';
            my $original_bam_path = $self->report_dir . '/data/' . $id . '_original_untrimmed.bam';
            my $humanfree_report_path = $self->report_dir . '/' . $id . '_humanfree_untrimmed_estimate_library_complexity_report.txt';
            my $original_report_path = $self->report_dir . '/' . $id . '_original_untrimmed_estimate_library_complexity_report.txt';

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
        my $other_stats_output_path = $self->report_dir . '/other_stats_report.txt';
        $self->status_message("Generating other stats...");
        unlink($other_stats_output_path) if (-f $other_stats_output_path);
        my $other_stats_output = Genome::Utility::FileSystem->open_file_for_writing($other_stats_output_path);

        for my $id (@imported_data_ids) {
            my $humanfree_report_path = $self->report_dir . '/' . $id . '_humanfree_untrimmed_estimate_library_complexity_report.txt';
            my $original_report_path = $self->report_dir . '/' . $id . '_original_untrimmed_estimate_library_complexity_report.txt';
            my $humanfree_report_fh = Genome::Utility::FileSystem->open_file_for_reading($humanfree_report_path);
            my $original_report_fh = Genome::Utility::FileSystem->open_file_for_reading($original_report_path);

            my $orig_data = $self->original_data_from_imported_id($id);
            my $lane = $orig_data->flow_cell_id . "_" . $orig_data->lane;

            while (my $line = $humanfree_report_fh->getline) {
                if ($line =~ /^##\ METRICS/) {
                    my $keys = $humanfree_report_fh->getline();
                    my $values = $humanfree_report_fh->getline();
                    my @keys = split("\t", lc($keys));
                    my @values = split("\t", $values);
                    my %metrics;
                    @metrics{@keys} = @values;
                    print $other_stats_output "$lane: Human-free Percent Duplication: " . $metrics{percent_duplication} . "\n";

                    $metric_name = "$lane\_humanfree_percent_duplication";
                    $metric{$metric_name}->delete() if($metric{$metric_name});
                    unless(Genome::Model::Metric->create(build_id => $self->build_id, name => $metric_name, value => $metrics{percent_duplication})) {
                        $self->error_message("Unable to create build metric (build_id=" . $self->build_id . ", $metric_name)");
                        die $self->error_message;
                    }

                    $metric_name = "$lane\_unique_humanfree_bases";
                    $metric{$metric_name}->delete() if($metric{$metric_name});
                    my $unique_bases_count = $humanfree_base_count{$id} * (1 - $metrics{percent_duplication});
                    unless(Genome::Model::Metric->create(build_id => $self->build_id, name => $metric_name, value => $unique_bases_count)) {
                        $self->error_message("Unable to create build metric (build_id=" . $self->build_id . ", $metric_name)");
                        die $self->error_message;
                    }
                    print $other_stats_output "$lane: Unique, human-free bases: $unique_bases_count\n";
                }
            }
            while (my $line = $original_report_fh->getline) {
                if ($line =~ /^##\ METRICS/) {
                    my $keys = $original_report_fh->getline();
                    my $values = $original_report_fh->getline();
                    my @keys = split("\t", lc($keys));
                    my @values = split("\t", $values);
                    my %metrics;
                    @metrics{@keys} = @values;
                    print $other_stats_output "$lane: Original Percent Duplication: " . $metrics{percent_duplication} . "\n";

                    $metric_name = "$lane\_original_percent_duplication";
                    $metric{$metric_name}->delete() if($metric{$metric_name});
                    unless(Genome::Model::Metric->create(build_id => $self->build_id, name => $metric_name, value => $metrics{percent_duplication})) {
                        $self->error_message("Unable to create build metric (build_id=" . $self->build_id . ", $metric_name)");
                        die $self->error_message;
                    }
                }
            }

        }

        $self->status_message("Removing unneeded FastQ files...");
        for my $id (keys %fastq_files) {
            last unless(exists($fastq_files{$id}) && exists($fastq_files{$id}{original}) && exists($fastq_files{$id}{imported}));
            unlink(@{$fastq_files{$id}{original}}[0]) if (-f @{$fastq_files{$id}{original}}[0]);
            unlink(@{$fastq_files{$id}{original}}[1]) if (-f @{$fastq_files{$id}{original}}[1]);
            unlink(@{$fastq_files{$id}{imported}}[0]) if (-f @{$fastq_files{$id}{imported}}[0]);
            unlink(@{$fastq_files{$id}{imported}}[1]) if (-f @{$fastq_files{$id}{imported}}[1]);

            my $humanfree_fwd_path = $temp_dir . '/' . $id . '_1_humanfree_untrimmed';
            my $humanfree_rev_path = $temp_dir . '/' . $id . '_2_humanfree_untrimmed';
            unlink($humanfree_fwd_path) if (-f $humanfree_fwd_path);
            unlink($humanfree_rev_path) if (-f $humanfree_rev_path);
        }


        print "\n\n";
        $self->status_message('Model: ' . $model->name);
        $self->status_message('Build: ' . $build->id);
        $self->status_message('Reports: ' . $self->report_dir);
        $self->status_message('Report Data: ' . $self->report_dir . '/data');
        my $done = system("touch ".$self->report_dir."/FINISHED");
        return 1;
    }

    sub original_data_from_imported_id {
        my ($self, $id) = @_;
        my $imported_data = Genome::InstrumentData::Imported->get($id);
        (my $alignment_id = $imported_data->original_data_path) =~ s/.*\/([0-9]*)\/.*/$1/;
        return Genome::InstrumentData::AlignmentResult->get($alignment_id)->instrument_data;
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

    sub expect64 {
        my $self = shift;
        my $uname = `uname -a`;
        unless ($uname =~ /x86_64/) {
            $self->error_message("Samtools requires a 64-bit operating system.");
            die $self->error_message;
        }
    }

    sub bam_stats_per_lane {
        my $self = shift;
        my $bam = shift;

        $self->expect64();
        my $bam_fh = IO::File->new("samtools view $bam |");
        unless($bam_fh) {
            $self->error_message("Failed to open $bam for reading.");
            die $self->error_message;
        }

        my %stats;
        my %flow_lane;
        my $total_reads_all_lanes;
        while (<$bam_fh>){
            my @fields = split("\t", $_);

            # count bases and reads
            my $seq = $fields[9];
            (my $id = $fields[11]) =~ s/.*://;

            # cache the flow_lane -> ID mapping
            unless($flow_lane{$id}) {
                my $data;
                $data = Genome::InstrumentData::Solexa->get($id);
                unless($data) {
                    $data = $self->original_data_from_imported_id($id);
                }
                unless($data) {
                    $self->error_message("Unable to find data (imported nor original) by ID $id.");
                    die $self->error_message;
                }
                $flow_lane{$id} = $data->flow_cell_id . '_' . $data->lane;
            }

            if ($seq eq '*'){
                $self->status_message("invalid sequence for read in bam: $_");
                next;
            }else{
                $stats{$flow_lane{$id}}{total_bases} += length($seq);
            }
            $total_reads_all_lanes++;
            $stats{$flow_lane{$id}}{total_reads}++;
            $self->status_message("\t\tProcessed " . $total_reads_all_lanes/1e6 . "M reads so far...") unless ($total_reads_all_lanes % 1e6);

            # percent mapped and duplication
            my $flag = $fields[1];
            if($flag & 0x0001) {
                $stats{$flow_lane{$id}}{paired_in_sequencing}++;                                    # the read is paired in sequencing, no matter whether it is mapped in a pair
                $stats{$flow_lane{$id}}{properly_paired}++              if(    $flag & 0x0002);     # the read is mapped in a proper pair (depends on the protocol, normally inferred during alignment) 1
                # these two did not match samtools flagstat when lanes combined, need to investigate further before enabling
                #$stats{$flow_lane{$id}}{singletons}++                   if(    $flag & 0x0008);     # the mate is unmapped 1
                #$stats{$flow_lane{$id}}{with_itself_and_mate_mapped}++  unless($flag & 0x0008);     # the mate is unmapped 1
                $stats{$flow_lane{$id}}{read1}++                        if(    $flag & 0x0040);     # the read is the first read in a pair 1,2
                $stats{$flow_lane{$id}}{read2}++                        if(    $flag & 0x0080);     # the read is the second read in a pair 1,2
            }
            $stats{$flow_lane{$id}}{mapped}++                           unless($flag & 0x0004);     # the query sequence itself is unmapped
            $stats{$flow_lane{$id}}{qc_failure}++                       if(    $flag & 0x0200);     # the read fails platform/vendor quality checks
            $stats{$flow_lane{$id}}{duplicates}++                       if(    $flag & 0x0400);     # the read is either a PCR duplicate or an optical duplicate
        }

        for my $id (keys %flow_lane) {
            $stats{$flow_lane{$id}}{paired_in_sequencing} ||= 0;
            $stats{$flow_lane{$id}}{properly_paired} ||= 0;
            $stats{$flow_lane{$id}}{singletons} ||= 0;
            $stats{$flow_lane{$id}}{with_itself_and_mate_mapped} ||= 0;
            $stats{$flow_lane{$id}}{read1} ||= 0;
            $stats{$flow_lane{$id}}{read2} ||= 0;
            $stats{$flow_lane{$id}}{mapped} ||= 0;
            $stats{$flow_lane{$id}}{qc_failure} ||= 0;
            $stats{$flow_lane{$id}}{duplicates} ||= 0;
            $stats{$flow_lane{$id}}{average_read_length} = $stats{$flow_lane{$id}}{total_bases}/$stats{$flow_lane{$id}}{total_reads};
            $stats{$flow_lane{$id}}{percent_mapped} = $stats{$flow_lane{$id}}{mapped}/$stats{$flow_lane{$id}}{total_reads};
            $stats{$flow_lane{$id}}{percent_duplicates} = $stats{$flow_lane{$id}}{duplicates}/$stats{$flow_lane{$id}}{total_reads};
            $stats{$flow_lane{$id}}{percent_properly_paired} = $stats{$flow_lane{$id}}{properly_paired}/$stats{$flow_lane{$id}}{total_reads};
        }
        return %stats;
    }

    1;

