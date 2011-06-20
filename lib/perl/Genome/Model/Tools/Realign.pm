package Genome::Model::Tools::Realign;

use strict;
use warnings;

use Genome;
use Data::Dumper;

use File::Temp qw(tempfile tempdir);
use Path::Class qw(file);


class Genome::Model::Tools::Realign {
    is  => 'Command',
    has => [
        regions_file => {
            type     => 'Text',
            is_input => 1,
            doc      =>
                "File containing regions to be realigned; TSV, leftmost columns: chr start stop"
        },
        bam => {
            type     => 'Text',
            is_input => 1,
            doc      =>
                "Alignment file in bam format"
        },
        lines_per_job => {
            type      => 'Number',
            is_input => 1,
            default   => 50,
        },
        output_dir => {
            type      => 'Text',
            is_output => 1,
        }
    ],
    has_optional => [
        first_line => {
            type => 'Number',
            is_input => 1,
        },
        last_line => {
            type => 'Number',
            is_input => 1,
        },
        worker_id => {
            type => 'Number',
            is_input => 1,
        },
        whole_file => {
            type => 'Boolean',
            is_input => 1,
        }
    ],
};

sub gatk_path {
    return '/gscuser/jlolofie/pkg/Sting/dist/';
}

sub human_ref_path {
    #TODO: check on tmp otherwise copy it
    return '/gscmnt/gc4096/info/reference_sequences/Homo_sapiens.NCBI36.45.dna.aml/all_sequences.fasta';
}

sub dbsnp_path {
    my $self = shift;
    
    my $model = Genome::Model->get( name => 'dbSNP-human-130-final-rod');
    unless($model) {
        $self->error_message("could not locade model dbSNP-human-130-final-rod which contains the necessary dbSNP file.");
        die $self->error_message;
    }
    my $path = $model->data_directory."/ImportedVariations/dbsnp_130_final.rod";
    unless(-s $path) {
        $self->error_message("could not locat dbSNP file");
        die $self->error_message;
    }
    return $path;
}

sub help_synopsis { 
    return <<EOS
gmt realign --bam my.bam --region_file my.regions --output_dir /shared/path --whole-file
EOS
}

sub help_detail {
    return <<EOS
Takes a bam and a file listing regions (chr/start/stop). Produces many smaller bam files
containing alignments from GATK local realigner.
EOS
}

sub execute { 

    my ($self) = @_;

    if ($self->whole_file()) {
        # partitions regions file, submits 1 worker job per partition
        # you end up with multiple smaller realigned bams
        $self->master_execute();
    } else {
        # creates 1 new bam with relaignments
        $self->worker_execute();
    }

    return 1;
}

sub worker_execute {

    my ($self) = @_;

    if (!defined($self->first_line())
        || !defined($self->last_line())
        || !defined($self->worker_id())) {
        die 'ERROR: You must specify first-line and last-line of '
            . 'regions file you would like to realign and worker-id (or use --whole-file for whole file)';
    }

    $self->make_output_dir(); # probably created by master_execute() already anyway

    # writing all this stuff to tmp
    my $tmp_dir = File::Temp->tempdir('realignXXXXX', CLEANUP => 1);
    my $mini_bam   = $self->create_mini_bam($tmp_dir);
    my $sorted_bam = $self->sort_rmdup_index_bam($mini_bam);

    # writing finally realignment bam to output_dir
    my $new_bam    = $self->realign($sorted_bam);

    print "created realigned bam: $new_bam\n";
    return 1;
}

sub make_output_dir {

    my ($self) = @_;

    my $output_dir = $self->output_dir();
    my $cmd = "mkdir -p $output_dir";

    my $r = system($cmd);
    if ( (defined($r) && $r > 0) 
        || ! -d $output_dir ) {
        die "ERROR: failed to mkdir: $output_dir";
    }

    return 1;
}

sub sort_rmdup_index_bam {

    my ($self, $bam) = @_;

    my ($bam_without_ext) = $bam =~ /(.*)\.bam/;
    $bam_without_ext .= '_sorted';

    my $sorted_bam = join('.', $bam_without_ext, 'bam');
    my $rmdup_bam = join('.', $bam_without_ext . '_rmdup' , 'bam');
    my $metrics_file = join('.', $bam_without_ext . '_rmdup' , 'metrics');

#               "&& samtools index $sorted_bam",
#               "&& samtools rmdup $sorted_bam $rmdup_bam",
    my @cmds = ("samtools sort $bam $bam_without_ext",
               "&& gmt sam mark-duplicates --file-to-mark $sorted_bam --marked-file $rmdup_bam --metrics-file $metrics_file",
               "&& samtools index $rmdup_bam"
    );

    my $cmd = join(' ', @cmds);

    my $r = system($cmd);
    if (defined($r) && $r > 0) {
        die "ERROR: failed during sort/dedup/index: $cmd";
    }

    my $index_pathname = join('.', $rmdup_bam, 'bai');
    if (! -f $index_pathname || (-s $index_pathname <= 0)) {
        die "ERROR: index is empty: $index_pathname";
    }

    return $rmdup_bam;
}

sub realign {

    my ($self, $partition_bam) = @_;

    my $interval_file = $self->generate_intervals_for_bam($partition_bam);
    my $realigned_bam = $self->realigned_bam_pathname();

#        '-sort NO_SORT',
   my $cmd = join( ' ',
        'java -Djava.io.tmpdir=/tmp',
        '-jar ' . $self->gatk_path() . '/GenomeAnalysisTK.jar',
        '-T IndelRealigner',
        '-maxReads 1000',
        "-I $partition_bam",
        '-R ' . $self->human_ref_path(),
        '--targetIntervals ' . $interval_file,
        "--output $realigned_bam" );

    my $exit_code = system($cmd);

    if (defined($exit_code) && $exit_code > 1) {
        die "ERROR: realignment exited with code: $exit_code: $cmd";
    }

    if (! -f $realigned_bam || (-s $realigned_bam <= 0)) {
        die "ERROR: realigned bam file is empty, must have failed: $cmd";
    }

    return $realigned_bam;
}

sub realigned_bam_pathname {

    my ($self) = @_;

    my $bam = file($self->bam());
    my $original_filename = $bam->basename();
    my ($uniq_bit) = $original_filename =~ /^(.*)\.bam$/;

    my $worker_id = sprintf("%05d", $self->worker_id());
    my $filename = join('_', $uniq_bit, 'part', $worker_id);
    $filename .= '.bam';

    my $pathname = join('/', $self->output_dir(), $filename);

    return $pathname;
}

sub generate_intervals_for_bam {

    my ($self, $partition_bam) = @_;

    my $file = file($partition_bam);
    my $tmp_dir = $file->dir();

    my ($fh, $temp_interval_file) = File::Temp->tempfile(
        'intervalsXXXXX',
        DIR     => $tmp_dir,
        SUFFIX  => '.intervals',
        CLEANUP => 0
    );

    my $cmd = join( ' ',
        'java',
        '-jar ' . $self->gatk_path() . '/GenomeAnalysisTK.jar',
        '-T RealignerTargetCreator',
        "-I $partition_bam",
        '-R ' . $self->human_ref_path(),
        "-o $temp_interval_file",
        '-B dbsnp,dbsnp,' . $self->dbsnp_path() );

    my $exit_code = system($cmd);

    if (defined($exit_code) && $exit_code > 1) {
        die "ERROR: failed to generate intervals, exit code: $exit_code: $cmd";
    }

    if (! -f $temp_interval_file || (-s $temp_interval_file <= 0)) {
        die "ERROR: interval file is empty, must have failed: $cmd";
    }

    return $temp_interval_file;
}

sub create_mini_bam {

    my ($self, $tmp_dir) = @_;

    my $ranges = $self->get_ranges();

    my ($fh, $minibam_filename) = File::Temp->tempfile(
        'minibam',
        DIR     => $tmp_dir,
        SUFFIX  => '.bam',
        CLEANUP => 0
    );

    my $cmd = join(' ', 'samtools view -b',
                        '-o',
                        $minibam_filename,
                        $self->bam(),
                        $ranges
                );

    my $exit_code = system($cmd);
    
    if (defined($exit_code) && $exit_code > 0) {
        die "Exited with code $exit_code: $cmd";
    }
  
    if (! -f $minibam_filename || (-s $minibam_filename <= 0)) {
        die "output file is empty, must have failed: $cmd";
    }
 
    return $minibam_filename; 
}

sub get_ranges {
    
    # parses file with leftmost columns: chr start stop
    # returns regions (chr:start-stop) seperated by space
    my ($self) = @_;
    my @ranges;

    my $first_line = $self->first_line();
    my $last_line = $self->last_line();

    my $file = $self->regions_file();
    open(my $fh, $file);
    my $i = -1;
    while (my $line = <$fh>) {
        $i++;

        if ($i < $first_line) {
            next;
        }

        if ($i > $last_line) {
            last; 
        }

        my ($chr, $start, $stop) = split(/\t/,$line);
        my $range = "$chr:$start-$stop";
        chomp($range);
        push @ranges, $range;
    }
    close($fh);

    my $range_params = join(' ', @ranges);
    return $range_params;
}

sub master_execute {

    my ($self) = @_;

    if (defined($self->first_line())
        || defined($self->last_line())
        || defined($self->worker_id())) {
        die 'ERROR: dont specify first or last line or worker-id if youre realigning the whole-file';
    }

    $self->make_output_dir();

    my $num_lines_in_file = $self->regions_file_line_count();

    my $n = $num_lines_in_file;
    my $partition = 1;

    my @jobs;

    my $log_pathname = $self->log_pathname();

    open(my $log_fh, ">$log_pathname");
    print "log is $log_pathname\n";

    while ($n > 0) {

        my ($job_id, $min, $max) = $self->submit_worker_job($partition, $num_lines_in_file);
        push @jobs, $job_id;

        $self->log($log_fh, $partition, $min, $max);

        $partition++;  # parition starts at 1
        $n -= $self->lines_per_job(); 
    }

    close($log_fh);

    my $job_id = $self->submit_master_job(\@jobs);
    return 1;
}


sub log {

    my ($self, $fh, $partition, $min, $max) = @_;

    my ($first_pos, $last_pos) = $self->get_positions($min, $max);
    my $log_msg = sprintf("%s\t%s\t%s\t%s\t%s\n", $partition, $min, $max, $first_pos, $last_pos);
    print $fh $log_msg;

    return 1;
}


sub get_positions {
    
    # returns the range (genomic position) between the first and last line of the region file
    #   for filtering out indels that should not be associated with a given minibam
    
    my ($self, $first, $last) = @_;

    open(my $fh, $self->regions_file);
    my $i = 0;
    my ($chr_pos1, $chr_pos2);

    while(my $line = <$fh>) {
     
        if ($first == $i) {
            my ($chr, $start) = split(/\t/,$line);
            $chr_pos1 = join(':', $chr, $start);
        } elsif($last == $i) {
            my ($chr, $start, $end) = split(/\t/,$line);
            $chr_pos2 = join(':', $chr, $end);
            last;
        }

        $i++;
    }

    close($fh);

    return ($chr_pos1, $chr_pos2);
}


sub log_pathname {

    my ($self) = @_;

    my $log = join("/",$self->output_dir, 'worker.log');
    return $log;
}


sub submit_worker_job {

    my ($self, $partition, $num_lines_in_file) = @_;

    my $n          = $self->lines_per_job();
    my $output_dir = $self->output_dir();

    my $min = $partition * $n - $n;
    my $max = $partition * $n - 1;

    if ($max > $num_lines_in_file) {
        $max = $num_lines_in_file
    }

    my $cmd = join(' ', 'bsub -q long -J realign_worker',
                        "gmt realign",
                        '--bam ' . $self->bam(),
                        '--regions-file ' . $self->regions_file(),
                        "--first-line $min",
                        "--last-line $max",
                        "--lines-per-job $n",
                        "--worker-id $partition",
                        "--output-dir $output_dir"
                    );

    my $r = `$cmd`;
    my ($jid) = $r =~ /Job \<(\d+)\>/;

    if ($jid) {
        print "worker $jid submitted\n";
    } else {
        die 'ERROR: failed to submit worker job';
    }

    return ($jid, $min, $max);
}

sub submit_master_job {

    # master job depends on all children exiting- successful or not
    # TODO: check for success by taking number of lines from intervals files, checking 
    #   filenames of generated realigned bam files

    my ($self, $jobs) = @_;
    my @ended_dep;

    for my $jid (@$jobs) {
        push @ended_dep, "ended($jid)";
    }

    my $ended_dep = join(' && ', @ended_dep);
    my $ended_cmd = join(' ', 
                        'bsub',
                        '-q long',
                        "-w \"$ended_dep\"",
                        '-J realign_ended_master',
                        'echo "local realignment worker jobs have ended"'
                    );

    my $r = `$ended_cmd`;
    my ($ended_jid) = $r =~ /Job \<(\d+)\>/;

    if ($ended_jid) {
        print "master $ended_jid submitted\n";
    } else {
        die 'ERROR: failed to submit master job';
    }

    return $ended_jid;
}

sub regions_file_line_count {

    my ($self) = @_;
    
    my $file = $self->regions_file();

    my $n = -1; # first line is 0
    open(my $fh, $file) || die "ERROR: cant open $file... $!";
    while(<$fh>) {
        $n++;
    }
    close($fh);

    return $n;
}

1;






=pod

=head1 Name

Genome::Model::Tools::Realign

=head1 Synopsis

Takes a bam and a file listing regions (chr/start/stop). Produces many smaller bam files
containing alignments from GATK local realigner.

=head1 Usage

    $ gmt realign --bam my.bam --region_file my.regions --output_dir /shared/path --whole-file
 
=cut




