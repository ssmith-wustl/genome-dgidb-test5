package Genome::Model::Tools::Maq::GenerateVariationMetrics;

use Genome;
use File::Basename;
use Genome;
class Genome::Model::Tools::Maq::GenerateVariationMetrics {
    is => 'Genome::Model::Tools::Maq',
    has => [
        input => {
            type => 'String',
            doc => 'File path for input map',
        },  
        snpfile => {
            type => 'String',
            doc => 'File path for snp file',
        },
        qual_cutoff => {
            type => 'int',
            doc => 'quality cutoff value', 
        },
        output => {
            type => 'String',
            doc => 'File path for input map', 
            is_optional => 1,
        },
        parallel_units => {
            is_optional => 1,
            type => 'Number',
            default_value => 1,
        },
    ],
};

sub help_brief {
    "remove extra reads which are likely to be from the same fragment based on alignment start site, quality, and sequence",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt remove-pcr-artifacts orig.map new_better.map removed_stuff.map --sequence-identity-length 26
EOS
}

sub help_detail {                           
    return <<EOS 
This tool removes reads from a maq map file which are likely to be the result of PCR, rather than distinct DNA fragments.
It examines all reads at the same start site, selects the read which has the best data to represent the group based on length and alignment quality.

A future enhancement would group reads with a common sequence in the first n bases of the read and select the best read from that group.
EOS
}

sub create {
    my $class = shift;    
    my $self = $class->SUPER::create(@_);    

    return $self;
}

sub execute {
    my $self = shift;
$DB::single = $DB::stopper;
    my $in = $self->input;
    my $snpfile = $self->snpfile;
    my $out = $self->output;
    #`cp $in /tmp/$out.map`;return 1;
    #print "input :$in \n snpfile: $snpfile \n out: $out\n";exit;
    if($in =~ /resolve/)
    {
        my ($eid, $library_name);
        ($eid, $library_name) = $in =~ /resolve (.*) (.*)/;
        ($eid) = $in =~ /resolve (.*)/ unless $library_name;

        my $e = Genome::Model::Event->get("$eid");
        my $model = $e->model;
        #print $model->name,"\n";
        $in = $e->resolve_accumulated_alignments_filename(
            ref_seq_id => $e->ref_seq_id,
            library_name => $library_name,
			force_use_original_files => 1
	   );
    }
    unless ($in and $snpfile and -e $in and -e $snpfile) {
        $self->error_message("Bad params!");
        $self->usage_message($self->help_usage_complete_text);
        return;
    }
    
    my $result;
    #$ovsrc =  `wtf Genome::Model::Tools::Maq::GenerateVariationMetrics_C`;
    #($ovsrc) = split /\n/,$ovsrc;
    #chomp $ovsrc;
    #`perl $ovsrc`;#evil hack
    #require Genome::Model::Tools::Maq::GenerateVariationMetrics_C;
    #$result = Genome::Model::Tools::Maq::GenerateVariationMetrics_C::filter_variations($in,$snpfile, 1,$out);#$qual_cutoff);
    
    #
    # Single-process
    #
    
    my $parallel_units = $self->parallel_units;
    if ($parallel_units < 2) {
        $result = system("/gscuser/jschindl/svn/dev/perl_modules/Genome/Model/Tools/Maq/ovsrc/maqval $in $snpfile 1 $out\n");
        $result = !$result; # c -> perl
        $self->result($result);
        return $result;
    }
    
    #
    # Multi-process
    #
    
    # divide the snpfile
    my $snpfh = IO::File->new($snpfile);
    my @snpfh_parts;
    for my $i (1..$parallel_units) {
        unless ($snpfh_parts[$i] = IO::File->new(">$snpfile-part.$i")) {
            die "Error opening temp file for part of the snps!"
        }
    }
    my $i=0;
    my @snpfh_sizes;
    while(my $line = <$snpfh>) {
        $snpfh_parts[$i]->print($line);
        $snpfh_sizes[$i]++;
        $i++;
        $i = 0 if $i == $parallel_units;
    }
    $snpfh->close;
    for(@snpfh_parts) { $_->close }
    
    # run jobs on each part
    my %running_jobs;
    my $hostname = `hostname -s`;
    for my $part (1..$parallel_units) {
        my $job = PP::LSF->create(
            hostname => $hostname,
            o => "$out-part$part.log",
            command => "/gscuser/jschindl/svn/dev/perl_modules/Genome/Model/Tools/Maq/ovsrc/maqval "
                . "$input_file $snpfile-part$part 1 $out-part$part\n"
        );
        unless ($job) {
            die "Can't create job: $!";
        }
        $job->start or die "Failed to start job for part $part!";
        $running_jobs{$job->id} = $job;
        $job_data{$job->id} = { retry_count => 3, retries => 0, part => $part };
    }
    
    # wait
    eval {
        while (%running_jobs) {
            sleep 30;
            for my $job_id ( keys %running_jobs ) {
                # Set local $job for clarity
                my $job = $running_jobs{$job_id};
                my $job_data = $job_data{$job_id};
                my $part = $job_data->{part};
                if ( $job->has_ended ) {
                    if ( $job->is_successful ) {
                        $self->status_message("$job_id (part $part) successful: " . $job->command . "\n");
                        my $out_part = "$out-part$part";
                        my $lines = 0;
                        eval { my $fh = IO::File->new($out_part); while ($_->getline) {$lines++} };
                        if (-e $out_part and -s $out_part and $lines==$snpfh_sizes[$part-1]) {
                            delete $running_jobs{$job_id};
                            next;
                        }
                        # msg the log, then fall through to failure code
                        if (not -e $out_part) {
                            $self->error_message("$job_id (part $part) output missing!");
                        }
                        elsif (not -s $out_part) {
                            $self->error_message("$job_id (part $part) output empty!");
                        }
                        elsif ($lines != $snpfh_sizes[$part-1]) {
                            $self->error_message(
                                "$job_id (part $part) has odd output size $lines, expecting "
                                . $snpfh_sizes[$part-1] . "!"
                            );
                        }
                        unlink $out_part;
                    }
                    
                    $self->error_message("$job_id (part $part) failed!");
                    my $log = "$out-part$part.log";
                    if (-e $log) {
                        my @log = eval { IO::File->new($log)->getlines; };
                        $self->error_message("$!: @log");
                    }
                    else {
                        $self->error_message("No log file!");
                    }
                    unlink $log;
                    unlink "core" if -e "core";
                    if($job_data->{retry_count} <= $job_data->{retries} ) {
                        $job_data->{retries}++;
                        $self->status_message("$job_data->{part} with job_id $job_id failed,"
                            . " retry number $job_data->{retries} of $job_data->{retry_count}\n"
                        );
                        $job->{job}->restart;
                        $self->status_message("restarted $job_data->{num}");
                    }
                    else {
                        print "$job_id failed, killing other jobs\n";
                        return;
                    }
                    
                } # done checking job
            } # next job
        } # next sleep iteration
    }; # end of loop
    
    if (%running_jobs) {
        for my $job ( values %running_jobs ) {
            next if $job->has_ended;
            $self->error_message("Killing job " . $job->id . ".  Command was: " . $job->command);
            eval { $job->kill; };
        }
        return;
    };
    
    my $merge_cmd = 
        'cat ' 
        . join(" ", map { "$out-part$_" } (1..$parallel_units)) 
        . " | sort -n -k 2 >$out";
    
    my $lines_expected  = 0;
    my $lines_actual    = 0;
    eval { my $fh = IO::File->new($in); while ($_->getline) {$lines_expected++} };
    eval { my $fh = IO::File->new($out); while ($_->getline) {$lines_actual++} };
    unless ($lines_expected == $lines_actual) {
        $self->error_message("Output file has unexpected line count $lines_actual.  Expected $lines_expected.");
        rename $out, $out . '-err' . $$;
        return;
    }
    
    return 1;
}

1;
