package PAP::Command::Blast::BladeBlastBatcher;

# bdericks: This module was originally written by Todd Wylie and named 
# BladeBlastBatcher_lowmemory_LSF. As of August 27, 2010, the original
# module can be found at /gscmnt/233/analysis/sequence_analysis/lib. I 
# wasn't able to find it in version control anywhere. I've made some
# changes to turn this into a command object and put in the PAP namespace

use strict;
use warnings;

use PAP;
use PP::LSF;
use Carp qw(confess);

class PAP::Command::Blast::BladeBlastBatcher {
    is => 'PAP::Command',
    has => [
        query_fasta_path => {
            is => 'Path',
            doc => 'Path to the original query FASTA file',
        },
        subject_fasta_path => {
            is => 'Path',
            doc => 'Path to the subject FASTA file',
        },
        lsf_queue => {
            is => 'Text',
            doc => 'The name of the LSF queue which the jobs will be submitted to',
        },
        lsf_job_limit => {
            is => 'Number',
            doc => 'The number of jobs to split the session into',
        },
        output_directory => {
            is => 'Path',
            doc => 'Output directory where all output will be directed',
        },
        blast_name => {
            is => 'Text',
            doc => 'Name of the BLAST type (e.g. tblastn, blastn, blastx)',
        },
    ],
    has_optional => [
        reports => {
            is => 'ARRAY',
            doc => 'Array of results produced by this module',
        },
        blast_params => {
            is => 'Text',
            default => "",
            doc => 'A string reserved for BLAST parameters',
        },
        lsf_mail_to => {
            is => 'Text',
            default => "",
            doc => 'Mail address that job summary emails are sent to',
        },
        lsf_resources => {
            is => 'Text',
            default => 'select[type==LINUX64]rusage[mem=7000]',
            doc => 'Resource string for each scheduled LSF job',
        },
        lsf_max_memory => {
            is => 'Number',
            default => '7000000',
            doc => 'Maximum allowable memory usage for each scheduled LSF job',
        },
    ],
};

sub help_detail {
    return <<EOS
PURPOSE:
This module was written to help developers who wish to smash a large
FASTA file into smaller sections and then run BLAST on them via the blade
center (qsub). Other scripts aid in doing this, but this module was
designed to accomplish the job inside of another, longer perl
application. Also, routines are supplied that help determine if the jobs
are finished on the blades, so the parent perl script may continue.
EOS
}

#TODO bdericks: I think this entire module can be vastly simplified by just
# using a Bio::SeqIO object to grab sequence out of the query fasta file rather
# than using regex to determine when a new sequence starts

# This routine (based on incoming values) will cut a given query FASTA file
# into XX number of smaller FASTA files, then run the chosen BLAST program
# on them by farming the jobs out to the blades. BLAST reports are written
# to a specified output directory. When all jobs are finished on the
# blades, this module sends the calling application back a list of report
# file paths.
sub execute {
    my $self = shift;
    my @reports;

    # Gather query file into a hash:
    my $fh_in = IO::File->new($self->query_fasta_path, "r");
    my $num_sequences;
    while (my $line = $fh_in->getline) {
        chomp $line;
        if ($line =~ /^>/) {
            $num_sequences++;
        }
    }

    $fh_in->close;
    my $chunk_size = int($num_sequences / $self->lsf_job_limit);
    my $remainder = int($num_sequences - ($chunk_size * $self->lsf_job_limit));
    my $last_chunk_size = $chunk_size + $remainder;

    # Write out to the sub-files:
    my @chunks;
    $fh_in = IO::File->new($self->query_fasta_path, "r");
    my $seq_counter;
    my $chunk_counter = 1;
    my $chunk = $self->output_directory . "/" . "CHUNK-1" . ".fasta";
    my $fh_out = IO::File->new($chunk, "a");
    my $current_chunk_size;
    while (my $line = $fh_in->getline) {
        chomp $line;
        if ($line =~ /^>/) {
            $seq_counter++;
            if ($chunk_counter == $self->lsf_job_limit) {
                $current_chunk_size = $last_chunk_size;
            }
            else {
                $current_chunk_size = $chunk_size;
            }

            if ($seq_counter > $current_chunk_size) {
                $seq_counter = 1;
                $chunk_counter++;
                push(@chunks, $chunk);
                $chunk = $self->output_directory . "/" . "CHUNK-" . $chunk_counter . ".fasta";
                $fh_out->close;
                $fh_out = IO::File->new($chunk, "a");
            }
        }
        $fh_out->print("$line\n");
    }
    push(@chunks, $chunk);
    $fh_in->close;
    $fh_out->close;

    # Configure & run each job on the blade center:
    my @jobs;
    for my $chunk (@chunks) {
        my $report = $chunk . ".blast.report";
        push @reports, $report;

        my $cmd;
        if ($self->blast_name eq "wu-blastall") {
            $cmd = $self->blast_name . " -d " . $self->subject_fasta_path . 
                " -i $chunk " . $self->blast_params . " > $report";
        } 
        else {
            $cmd = join(" ", $self->blast_name, $self->subject_fasta_path, $chunk, $self->blast_params) . 
                " > $report";
        }

        my $bsub = PP::LSF->create(
            'q'           => $self->lsf_queue,
            'o'           => $self->output_directory,
            'e'           => $self->output_directory,
            'R'           => "'" . $self->lsf_resources . "'",
            'M'           => $self->lsf_max_memory,
            'mailto'      => $self->lsf_mail_to,       
            'command'     => "\"" . $cmd . "\"",
        );
        $bsub->start;
        push @jobs, $bsub;
    }

    # Probably not the best way to wait for all the jobs to finish, but it works
    for my $job (@jobs) {
        $job->wait_on;
    }

    # The blade jobs have finished, return a list of report paths to the user:
    $self->reports(\@reports);
    return 1;
}

# ---------------------------------------------------------------------------
# D O C U M E N T A T I O N
# ---------------------------------------------------------------------------

=head1 NAME

I<BladeBlastBatcher.pm>

=head1 VERSION

version 1.0 [April 2005]

=head1 DESCRIPTION

This module was written to help developers who wish to smash a large FASTA file into smaller sections and then run BLAST on them via the blade center (qsub). Other scripts aid in doing this, but this module was designed to accomplish the job inside of another, longer perl application. Also, routines are supplied that help determine if the jobs are finished on the blades, so the parent perl script may continue.

=head1 SYNOPSIS

To perform a simple call from a perl script:

  my @reports = &PAP::Command::Blast::BladeBlastBatcher->execute(
                          query        => $query,
                          subject      => $revised_subject,
                          queue        => "compbio\@qblade",
                          load         => $blades,
                          outdir       => $SessionOutDir,
                          blast_name   => "blastx",
                          blast_params => "-b 10000",
                          mailoptions  => "abe",
                          mailto       => "twylie\@watson.wustl.edu"
                                               );


CONFIGURATION:

=over 5

=item 1

query:        The path to the original query FASTA file.				 

=item 2

subject:      The path to the subject FASTA file.					 

=item 3

queue:        The name of the blade queue which the jobs will be submitted to.	 

=item 4

load:         The number of jobs to split the session into.			 

=item 5

outdir:       Output directory where all output will be directed.			 

=item 6

blast_name:   Name of the BLAST type (e.g. tblastn, blastn, blastx).		 

=item 7

blast_params: A string reserved for BLAST parameters [OPTIONAL].		 

=item 8

mailoptions:  Qsub switch reserved to provide mailing options [OPTIONAL].		 

=item 9

mailto:       Qsub switch reserved for mail address [OPTIONAL].                    

=back

NOTE: The following params are optional: blast_params, mailoptions, mailto. The mailoptions & mailto params must both be present to work correctly.

=head1 AUTHOR

 Todd Wylie
 CompBio
 Genome Sequencing Center
 Washington University
 School of Medicine
 4444 Forest Park Boulevard
 St. Louis, MO 63108

CONTACT: twylie@watson.wustl.edu

=head1 LIMITATION/BUGS

=over 5

=item 1

Mail function has not been tested properly as of Tue Apr 26 16:05:53 CDT 2005. This may be a qsub glitch--but should be resolved at a later date (time permitting).

=item 2

Only "blastx" has been tested for v1.0 release. Other blast types should be tested.

=back

Please contact the author if any complications are encountered.

=head1 COPYRIGHT

Copyright (C) 2005 by Todd Wylie and Washington University School of Medicine Genome Sequencing Center.

=head1 NOTE:

This software was written using the latest version of GNU Emacs, the extensible, real-time text editor. Please see http://www.gnu.org/software/emacs/ for more information and download sources.

=cut
