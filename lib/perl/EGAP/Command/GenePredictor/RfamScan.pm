package EGAP::Command::GenePredictor::RfamScan;

use strict;
use warnings;

use EGAP;
use Carp 'confess';
use File::Temp;

class EGAP::Command::GenePredictor::RfamScan {
    is => 'EGAP::Command::GenePredictor',
    has_optional => [
        rfam_install_path => {
            is => 'Path',
            default => '/gsc/pkg/bio/rfam/',
            doc => 'Base installation path of rfam',
        },
        version => {
            is => 'Text',
            valid_values => ['7.0', '8.0', '8.1'],
            default => '8.1',
            doc => 'Version of rfam to use',
        },
        output_format => {
            is => 'Text',
            valid_values => ['tab', 'gff'],
            default => 'tab',
            doc => 'Output format used by rfam, either tab-delimited or gff2',
        },
        # TODO There are a bunch of other parameters that could be added here,
        # just type rfam_scan -h for a full list. For now, these aren't needed.
    ],
};

sub help_brief {
    return 'Executes rfam_scan on the provided fasta file';
}

sub help_synopsis {
    return 'Executes rfam_scan on the provided fasta file';
}

sub help_detail {
    return <<EOS
Runs rfam_scan on the provided fasta file, captures raw output in the
provided directory, and parses that output and creates RNAGene objects.
EOS
}

sub execute {
    my $self = shift;
    my $program_dir = $self->rfam_install_path . '/rfam-' . $self->version . '/';
    my $program_path = $program_dir . 'rfam_scan.pl';
    confess "No rfam_scan program found at $program_path!" unless -e $program_path;

    my $raw_output_fh = File::Temp->new(
        DIR => $self->raw_output_directory,
        TEMPLATE => 'rfam_scan_raw_output_XXXXXX',
        UNLINK => 0,
        CLEANUP => 0,
    );
    my $raw_output_file = $raw_output_fh->filename;
    $raw_output_fh->close;

    my @params;
    push @params, '-f ' . $self->output_format;
    push @params, "-o $raw_output_file ";
    push @params, $self->fasta_file;
    
    my $cmd = join(" ", $program_path, @params);
    $self->status_message("Preparing to execute rfam_scan: $cmd");

    # Unfortunately, rfam scan requires that an environment variable be set to execute...
    $ENV{RFAM_DIR} = $program_dir;
    my $rv = system($cmd);
    confess 'Trouble executing rfam_scan!' unless defined $rv and $rv == 0;
    return 1;
}

1;
