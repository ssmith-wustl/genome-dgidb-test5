package Genome::Model::Command::Report::VariationsBatchToLsf;

use strict;
use warnings;

use above "Genome";

use Genome::Model::Command::Report::Variations;
use Command; 
use PP::LSF;

class Genome::Model::Command::Report::VariationsBatchToLsf 
{
    is => 'Genome::Model::Command::Report::Variations',                       
    has => 
    [ 
    out_log_file => 
    {
        type => 'String',
        is_optional => 1,
        doc => "Will combine the LSF output files into this file",
    },
    error_log_file => 
    {
        type => 'String',
        is_optional => 1,
        doc => "Will combine the LSF error files into this file",
    },
    ],
};

#########################################################

sub sub_command_sort_position { 90 } # FIXME needed?

sub help_brief {
    return "Generates an annotation report for a variation file."
}

sub help_synopsis {
    return;
}

sub help_detail {
    return <<"EOS"
    For a given variant file, this module will split it up into files containing 10000 variants.  Then for each of these split files, a job will be spawned and monitored that will run Genome::Model::Command::Report::Variation.  When the jobs are completed, the resulting report files will be combined into one report.  If requested the output and error logs from lsf can also be combined.
EOS
}

sub execute {
    my $self = shift;
    
    # create child jobs
    my $jobs = $self->_create_jobs;
    $self->error_message("No jobs created")
        and return unless $jobs and @$jobs;

    # run & monitor jobs
    my $success = $self->_run_and_monitor_jobs($jobs);

    # finish
    return $self->_finish($success, $jobs);
}

sub _create_jobs
{
    my $self = shift;

    my $main_variant_fh = $self->_open_read_fh( $self->variant_file )
        or return;

    my @jobs;
    my $line_count = 0;
    while ( my $line = $main_variant_fh->getline )
    {
        $line_count++;
        if ( $line_count == 1 )
        {
            unless ( push @jobs, $self->_setup_job($#jobs + 1) )
            {
                $self->_finish(0, \@jobs);
                return; 
            }
            $jobs[$#jobs]->{variant_fh}->print($line);
        }
        elsif ( $line_count == 10000 ) # TODO param??
        {
            $jobs[$#jobs]->{variant_fh}->print($line);
            $jobs[$#jobs]->{variant_fh}->close;
            $line_count = 0;
        }
        else
        {
            $jobs[$#jobs]->{variant_fh}->print($line);
        }
    }

    $jobs[$#jobs]->{variant_fh}->close if $jobs[$#jobs]->{variant_fh}->opened;
    $main_variant_fh->close;

    return \@jobs;
}

sub _open_fh
{
    my ($self, $file, $mode) = @_;

    my $fh = IO::File->new("$mode $file");
    warn("Can't open file ($file)")
        and return unless $fh;

    return $fh;
}

sub _open_read_fh
{
    my ($self, $file) = @_;

    return $self->_open_fh($file, '<');
}

sub _open_write_fh
{
    my ($self, $file) = @_;

    unlink $file if -e $file;

    return $self->_open_fh($file, '>');
}

sub _setup_job
{
    my ($self, $num) = @_;

    my $variant_file = sprintf
    (
        '%s.%d', 
        $self->variant_file,
        $num,
    );
    unlink $variant_file if -e $variant_file;
    my $variant_fh = $self->_open_write_fh($variant_file)
        or return;
    
    my $report_file_base = sprintf
    (
        '%s.%d', 
        $self->report_file_base,
        $num,
    );

    # If logging, get a log file for each job
    my ($out_file, $error_file);
    if ( $self->out_log_file )
    {
        $out_file = sprintf
        (
            '%s.%d', 
            $self->out_log_file, 
            $num,
        );
        unlink $out_file if -e $out_file;
    }

    if ( $self->error_log_file )
    {
        $error_file = sprintf
        (
            '%s.%d', 
            $self->error_log_file, 
            $num,
        );
        unlink $error_file if -e $error_file;
    }

    my %job_params =
    (
        pp_type => 'lsf',
        q => 'aml',
        R => "'select[db_dw_prod_runq<10] rusage[db_dw_prod=1]'",
        command => sprintf
        (
            '`which genome-model` report variations --report-file-base %s --variant-file %s --variant-type %s --flank-range %s --variation-range %s --minimum-maq-score %s --minimum-read-count %s --no-header',
            $report_file_base,
            $variant_file,
            $self->variant_type,
            $self->flank_range,
            $self->variation_range,
            $self->minimum_maq_score,
            $self->minimum_read_count,
        ),
    );

    # print $job_params{command},"\n";

    $job_params{o} = $out_file if $out_file;
    $job_params{e} = $error_file if $error_file;

    my $job = PP::LSF->create(%job_params);
    $self->error_message("Can't create job: $!")
        and return unless $job;

    return 
    {
        job => $job,
        variant => $variant_file,
        variant_fh => $variant_fh,
        report_file_base => $report_file_base,
        out => $out_file,
        error => $error_file,
    };
}

sub _run_and_monitor_jobs
{
    my ($self, $jobs) = @_;

    # Start jobs.  To monitor, create hash w/ job ids as keys.
    my %running_jobs;
    for my $num ( 0..(scalar(@$jobs) - 1) )
    {
        # Set local $job for clarity
        my $job = $jobs->[$num]->{job};
        $job->start;
        $running_jobs{ $job->id } = $num;
    }

    # Monitor
    MONITOR: while ( %running_jobs )
    {
        sleep 30;
        for my $job_id ( keys %running_jobs )
        {
            # Set local $job for clarity
            my $job = $jobs->[ $running_jobs{$job_id} ]->{job};
            if ( $job->has_ended )
            {
                if ( $job->is_successful )
                {
                    print "$job_id successful\n";
                    delete $running_jobs{$job_id};
                }
                else
                {
                    print "$job_id failed, killing other jobs\n";
                    $self->_kill_jobs($jobs);
                    last MONITOR;
                }
            }
        }
    }

    return ( %running_jobs ) ? 0 : 1; # success is going thru all running jobs 
}

sub _kill_jobs
{
    my ($self, $jobs) = @_;

    for my $job_ref ( @$jobs )
    {
        my $job = $job_ref->{job};
        next if $job->has_ended;
        $job->kill;
    }
    
    return 1;
}

sub _finish
{
    my ($self, $success, $jobs) = @_;

    # Create the main reports, if jobs were successful
    my %report_fhs;
    if ( $success )
    {
        REPORT_TYPE: for my $report_type ( $self->report_types )
        {
            my $report_file = $self->_report_file($self->report_file_base, $report_type);
            unlink $report_file if -e $report_file;
            my $report_fh = IO::File->new("> $report_file");
            $self->error_message("Can't open $report_type report file for writing") 
                and next REPORT_TYPE unless $report_fh;
            my $headers_method = sprintf('%s_report_headers', $report_type);
            $report_fh->print( join(',', $self->$headers_method), "\n" ) unless $self->no_headers;
            $report_fhs{$report_type} = $report_fh;
        }
    }

    JOB: for my $job ( @$jobs )
    {
        LOG_TYPE: for my $log_type (qw/ out error /)
        {
            my $log_file_method = $log_type . '_log_file';
            my $log_file = $self->$log_file_method;
            next LOG_TYPE unless $log_file and -e $job->{$log_type};
            # cat the log file
            system sprintf('cat %s >> %s', $job->{$log_type}, $log_file);
            # remove the job's log file
            unlink $job->{$log_type};
        }

        # remove the chunked variant file
        unlink $job->{variant} if -e $job->{variant};

        # combined the chunked report w/ the main report
        REPORT_TYPE: for my $report_type ( $self->report_types )
        {
            my $chunked_file = $self->_report_file
            (
                $job->{report_file_base},
                $report_type,
            );
            next REPORT_TYPE unless -e $chunked_file;

            if ( $success )
            {
                my $chunked_fh = IO::File->new("< $chunked_file");
                if ( $chunked_fh )
                {
                    while ( my $line = $chunked_fh->getline )
                    {
                        $report_fhs{$report_type}->print($line);
                    }
                }
                else
                {
                    $self->error_message("Can't open $report_type report file for reading");
                }
            }

            # remove the chunked report
            unlink $chunked_file; 
        }
    }

    for my $fh ( values %report_fhs )
    {
        $fh->close;
    }

    return $success;
}

1;

=pod 

=head1 Name

Genome::Model::Command::Report::VariationsBatchToLsf

=head1 Synopsis

For a given variant file, this module will split it up into files containing 10000 variants.  Then for each of these split files, a job will be spawned and monitored that will run Genome::Model::Command::Report::Variation.  When the jobs are completed, the resulting report files will be combined into one report.  If requested the output and error logs from lsf can also be combined.

=head1 Usage

 $success = Genome::Model::Command::Report::VariationsBatchToLsf->execute
 (
     variant_type => 'snp', # opt, default snp, valid types: snp, indel
     variant_file => $detail_file, # req
     report_file => sprintf('%s/variant_report_for_chr_%s', $reports_dir, $chromosome), # req
     out_log_file => 'out', # opt, combine the out lsf log files here
     error_log_file => 'err', # opt, combine the error lsf log files here
     flank_range => 10000, # opt, default 50000
     variant_range => 0, # opt, default 0
 );

 if ( $success )
 { 
    ...
 }
 else 
 {
    ...
 }
 
=head1 Methods

=head2 execute or create then execute

=over

=item I<Synopsis>   Gets all annotations for a snp

=item I<Arguments>  snp (hash; see 'SNP' below)

=item I<Returns>    annotations (array of hash refs; see 'Annotation' below)

=back

=head1 See Also

B<Genome::SnpAnnotator>, B<Genome::Model::Command::Report::Variations>, B<Genome::DB::*>, B<Genome::DB::Window::*>

=head1 Disclaimer

Copyright (C) 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
