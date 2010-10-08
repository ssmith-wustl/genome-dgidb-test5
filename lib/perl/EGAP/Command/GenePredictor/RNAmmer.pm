package EGAP::Command::GenePredictor::RNAmmer;

use strict;
use warnings;

use EGAP;
use Carp 'confess';
use Bio::Tools::GFF;

class EGAP::Command::GenePredictor::RNAmmer {
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
        domain => {
            is => 'Text',
            is_input => 1,
            valid_values => ['archaeal', 'bacterial', 'eukaryotic'],
            default => 'eukaryotic',
        },
        version => {
            is => 'Text',
            is_input => 1,
            default => '1.2',
            doc => 'Version of rnammer to use',
        },
        molecule_type => {
            is => 'Text',
            doc => 'Specifies molecule types',
            default => 'tsu,lsu,ssu',
        },
        output_format => {
            is => 'Text',
            default => 'gff',
            valid_values => ['fasta', 'gff', 'xml'],
            doc => 'Format of output file',
        },
        temp_working_dir => {
            is => 'Path',
            default => '/tmp/',
            doc => 'Place for temporary files, cleaned up unless keep is set to true',
        },
        debug => {
            is => 'Boolean',
            default => 0,
            doc => 'If set, debugging information is displayed',
        },
        keep => {
            is => 'Boolean',
            default => 0,
            doc => 'If set, temporary files are kept',
        },
        parallel_execution => { 
            is => 'Boolean',
            default => 0,
            doc => 'If set, rnammer is run in parallel',
        },
    ],
};

sub help_brief {
    "Write a set of fasta files for an assembly";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    my $self = shift;
    my $fasta_file = $self->fasta_file;

    # TODO Logic for this output format needs to be added
    if ($self->output_format ne 'gff') {
        $self->error_message("Only GFF output format is currently supported, sorry!");
        confess;
    }

    my $rnammer_path = "/gsc/pkg/bio/rnammer/rnammer-" . $self->version . "/rnammer";
    confess "No rnammer executable found at $rnammer_path!" unless -e $rnammer_path;

    # Create a list of parameters
    my @params;
    push @params, "-T " . $self->temp_working_dir;
    push @params, "-S " . substr($self->domain, 0, 3);
    push @params, "-m " . $self->molecule_type;
    push @params, "-d " if $self->debug;
    push @params, "-multi " if $self->parallel_execution;
    push @params, "-k " if $self->keep;
   
    # Get output file name and creaet output param for command
    my ($suffix, $param);
    if ($self->output_format eq 'fasta') {
        $suffix .= ".fa";
        $param = "-f ";
    }
    elsif ($self->output_format eq 'gff') {
        $suffix = ".gff";
        $param = "-gff ";
    }
    elsif ($self->output_format eq 'xml') {
        $suffix = ".xml";
        $param = "-xml ";
    }
    my $output_file_fh = File::Temp->new(
        DIR => $self->raw_output_directory,
        TEMPLATE => "rnammer_raw_output_XXXXXX",
        UNLINK => 0,
        CLEANUP => 0,
        SUFFIX => $suffix,
    );
    my $output_file = $output_file_fh->filename;
    $output_file_fh->close;
    push @params, $param . $output_file;

    push @params, $fasta_file;

    # Create and execute command
    my $cmd = join(" ", $rnammer_path, @params);
    $self->status_message("Executing rnammer: $cmd");
    my $rna_rv = system($cmd);
    confess "Trouble executing rrnamer!" unless defined $rna_rv and $rna_rv == 0;

    # TODO Add parsing logic for fasta and xml
    if ($self->output_format eq 'gff') {
        # Version 1 is the only version that correctly parses the last column of output...
        my $gff = Bio::Tools::GFF->new(
            -file => $output_file,
            -gff_version => 1,
        );

        my $feature_counter = 0;
        while (my $feature = $gff->next_feature()) {
            $feature_counter++;
            my $gene_name = join(".", $feature->seq_id(), 'rnammer', $feature_counter);
            my ($description) = $feature->get_tag_values('group');

            my $start = $feature->start();
            my $end = $feature->end();
            ($start, $end) = ($end, $start) if $start > $end;

            $DB::single = 1;
            my $sequence = EGAP::Sequence->get(
                file_path => $self->egap_sequence_file,
                sequence_name => $feature->seq_id(),
            );
            my $seq_string = $sequence->sub_sequence($start, $end);

            my $rna_gene = EGAP::RNAGene->create(
                file_path => $self->rna_prediction_file,
                gene_name => $gene_name,
                source => $feature->source_tag(),
                description => $description,
                start => $start,
                end => $end,
                sequence_name => $feature->seq_id(),
                sequence_string => $seq_string,
                strand => $feature->strand(),
                score => $feature->score(),
            );
            confess "Could not create rna gene object!" unless $rna_gene;
        }
    }

    # TODO Add locking here
    UR::Context->commit;
    $self->status_message("rnammer suceessfully completed!");
    return 1;
}

1;
