package Genome::Model::Command::Report::VariationsBatchToLsf;

use strict;
use warnings;

use above "Genome";

use Genome::Model::Command::Report::Variations;
use Command; 
use PP::LSF;

class Genome::Model::Command::Report::VariationsBatchToLsf 
{
    is => 'Command',                       
    has => 
    [ 
    variant_file => 
    {
        type => 'String',
        is_optional => 0,
        doc => "File of variants",
    },
    report_file => 
    {
        type => 'String',
        is_optional => 0,
        doc => "File to put annotations",
    },
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
    chromosome_name => 
    {
        type => 'String',
        doc => "Name of the chromosome AKA ref_seq_id", 
        is_optional => 0,
    },
    variation_type => 
    {
       type => 'String', 
       is_optional => 1,
       default => 'snp',
       doc => "Type of variation: snp, indel",
    },
    flank_range => 
    {
        type => 'Integer', 
        is_optional => 1,
        default => 50000,
        doc => "Range to look around for flaking regions of transcripts",
    },
    variation_range => 
    {
       type => 'Integer', 
       is_optional => 1,
       default => 0,
       doc => "Range to look around a variant for known variations",
    },
    #format => 
    #{
    #   type => 'String', 
    #   doc => "?",
    #   is_optional => 0,
    #},
    ],
};

#########################################################

sub sub_command_sort_position { 90 } # FIXME needed?

sub help_brief {
    "Generates an annotation report for a variation file."
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
    
    my $chromosome = $self->chromosome_name;
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

    # Run & monitor jobs, then finish
    return $self->_finish( $self->_run_and_monitor_jobs(\@jobs), \@jobs );
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

    my $chromosome_name = $self->chromosome_name;

    my $variant_file = sprintf
    (
        '%s.%d', 
        $self->variant_file,
        $num,
    );
    unlink $variant_file if -e $variant_file;
    my $variant_fh = $self->_open_write_fh($variant_file)
        or return;
    
    my $report_file = sprintf
    (
        '%s.%d', 
        $self->report_file,
        $num,
    );
    unlink $report_file if -e $report_file;

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
            '`which genome-model` report variations --report-file %s --variant-file %s --chromosome-name %s --variation-type %s --flank-range %s --variation-range %s',
            $report_file,
            $variant_file,
            $chromosome_name,
            $self->variation_type,
            $self->flank_range,
            $self->variation_range,
        ),
    );

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
        report => $report_file,
        out => $out_file,
        error => $error_file,
    };
}

sub _run_and_monitor_jobs
{
    my ($self, $jobs) = @_;

    # Start
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
                if ( $job->has_ended )
                {
                    if ( $job->is_successful )
                    {
                        print "$job_id successful\n";
                        delete $running_jobs{$job_id};
                    }
                    else
                    {
                        print "$job_id failed\n";
                        $self->_kill_jobs($jobs);
                        last MONITOR;
                        # return;
                    }
                }
            }
        }
    }

    return ( %running_jobs ) ? 0 : 1; # success is going thru all running jobs 
    #return 1;
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

sub _combine_and_remove_report_files
{
    my ($self, $jobs) = @_;

    my $report_file = $self->report_file;
    unlink $report_file if -e $report_file;

    JOB: for my $job ( @$jobs )
    {
        unlink $job->{variant} if -e $job->{variant};
        $self->error_msg
        (
            'Can\'t find report portion (%s) for chromosome (%s)', $job->{report}, $self->ref_seq_id
        ) and next JOB unless -e $job->{report};
        system sprintf('cat %s >> %s', $job->{report}, $report_file);
        unlink $job->{report}; 
    }

    return 1;
}

sub _combine_and_remove_lsf_files
{
    my ($self, $jobs) = @_;

    LOG_TYPE: for my $log_type (qw/ out error /)
    {
        my $log_file_method = $log_type . '_log_file';
        my $log_file = $self->$log_file_method;
        next LOG_TYPE unless $log_file;
        JOB: for my $job ( @$jobs )
        {
            next JOB unless -e $job->{$log_type};
            system sprintf('cat %s >> %s', $job->{$log_type}, $log_file);
            # print??
            unlink $job->{$log_type};
        }
    }

    return 1;
}

sub _finish
{
    my ($self, $success, $jobs) = @_;

    $self->_combine_and_remove_report_files($jobs) if $success;
    $self->_combine_and_remove_lsf_files($jobs);

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
     chromosome_name => $chromosome, # req
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
