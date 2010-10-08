package EGAP::Command::GenePredictor::RfamScan;

use strict;
use warnings;

use EGAP;
use Carp 'confess';
use File::Temp;
use File::Path 'make_path';

class EGAP::Command::GenePredictor::RfamScan {
    is => 'EGAP::Command::GenePredictor',    
    has => [
        rna_prediction_file => {
            is => 'Path',
            is_input => 1,
            is_output => 1,
            doc => 'RNA gene predictions are placed in this file',
        },
    ],
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
    # Figure out the exact path to the executable instead of relying on a symlink in /gsc/scripts/bin, which
    # prevents silent upgrades from changing the executable we use!
    my $program_dir = $self->rfam_install_path . '/rfam-' . $self->version . '/';
    my $program_path = $program_dir . 'rfam_scan.pl';
    confess "No rfam_scan program found at $program_path!" unless -e $program_path;

    unless (-d $self->raw_output_directory) {
        my $mkdir_rv = make_path($self->raw_output_directory);
        confess 'Could not make directory ' . $self->raw_output_directory unless $mkdir_rv;
    }
        
    my $raw_output_fh = File::Temp->new(
        DIR => $self->raw_output_directory,
        TEMPLATE => 'rfam_scan_raw_output_XXXXXX',
        UNLINK => 0,
        CLEANUP => 0,
    );
    my $raw_output_file = $raw_output_fh->filename;
    $raw_output_fh->close;

    # Create a list of parameters and then create the command string
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
    delete $ENV{RFAM_DIR};

    my $output_fh = IO::File->new($raw_output_file, 'r');
    confess "Couldn't get file handle for $raw_output_file for raw output parsing!" unless $output_fh;

    # Parse output and create RNAGene objects
    my %sequence_counts;
    while (my $line = $output_fh->getline) {
        chomp $line;
        my ($sequence_id, $start, $end, $accession, $model_start, $model_end, $bit_score, $rfam_id) = split(/\s+/, $line);

        my $strand = 1;
        $strand = -1 if $start > $end;

        # The sequence ids are not sorted in the rfamscan output file, so using a hash to track the number
        # of previous predictions for the sequence is necessary to create a unique gene_name.
        $sequence_counts{$sequence_id}++;
        my $gene_name = $sequence_id . ".rfam." . $sequence_counts{$sequence_id};

        my $rna_gene = EGAP::RNAGene->create(
            file_path => $self->rna_prediction_file,
            gene_name => $gene_name,
            description => $rfam_id,
            start => $start,
            end => $end,
            strand => $strand,
            accession => $accession,
            score => $bit_score,
            source => 'rfam',
            sequence_name => $sequence_id,
        );
    }

    # TODO Add file locking
    UR::Context->commit;
    $self->status_message("rfamscan successfully completed!");
    return 1;
}

1;
