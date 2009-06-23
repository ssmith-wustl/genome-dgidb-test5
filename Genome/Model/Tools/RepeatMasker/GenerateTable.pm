package Genome::Model::Tools::RepeatMasker::GenerateTable;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RepeatMasker::GenerateTable {
    is => ['Command'],
    has => [
        fasta_file => {
            is => 'Text',
            doc => 'The masked file output from RepeatMasker(.masked) or original fasta of all sequences',
        },
        output_file => {
            is => 'Text',
            doc => 'The output from repeat masker(.out)',
        },
        table_file => {
            is => 'Text',
            doc => 'This is the file location where the output table from this command will be written.  This is not the RepeatMasker(.tbl)',
        },
    ],
};

sub execute {
    my $self = shift;

    my $fasta_reader = IO::File->new($self->fasta_file,'r');
    unless ($fasta_reader) {
        die('Failed to open fasta file '. $self->fasta_file);
    }
    my $total_bp = 0;
    my $total_count = 0;
    eval {
        local $/ = "\n>";
        while (<$fasta_reader>) {
            if ($_) {
                chomp;
                if ($_ =~ /^>/) { $_ =~ s/\>//g }
                my $myFASTA = FASTAParse->new();
                $myFASTA->load_FASTA( fasta => '>' . $_ );
                my $seqlen = length( $myFASTA->sequence() );
                $total_bp += $seqlen;
                $total_count++;
                # TODO: GC content?
                # TODO: masked bases or just get from alignments below
            }
        }
    };
    $fasta_reader->close;
    if ($@) {die ($@); }

    my $parser = Bio::Tools::RepeatMasker->new(-file => $self->output_file);
    unless ($parser) {
        die ('Failed to create RepeatMasker parser for file: '. $self->output_file);
    }
    my %repeats;
    while (my $result = $parser->next_result) {
        my $tag = $result->hprimary_tag;
        my ($family,$class) = split("/",$tag);
        unless (defined($class)) {
            if ($family =~ /RNA/) {
                $family = 'Small RNA';
            }
            $class = 0;
        }
        $repeats{$family}{$class}{elements}++;
        # Take either the hit length or the query length, but we are not accounting insertions/deletions/mismatches
        my $length = (($result->end - $result->start) + 1);
        if ($length < 1) {
            die(Data::Dumper::Dumper($result));
        }
        $repeats{$family}{$class}{base_pair} += $length;
    }
    my $masked_bp = 0;
    my $family_string = '';
    for my $family (keys %repeats) {
        my $family_bp;
        my $family_elements;
        my $class_string = '';
        for my $class (keys %{$repeats{$family}}) {
            my $class_elements = $repeats{$family}{$class}{elements};
            my $class_bp = $repeats{$family}{$class}{base_pair};
            my $class_pc = sprintf("%.02f",(($class_bp / $total_bp ) * 100)) .'%';
            if ($class) {
                $class_string .= "\t". $class .":\t". $class_elements ."\t". $class_bp ."\t". $class_pc."\n";
            }
            $family_bp += $class_bp;
            $family_elements += $class_elements;
        }
        my $family_pc = sprintf("%.02f",(($family_bp / $total_bp ) * 100)) .'%';
        $family_string .= $family .":\t". $family_elements ."\t". $family_bp ."\t". $family_pc."\n";
        $family_string .= $class_string ."\n";
        $masked_bp += $family_bp;
    }

    my $table_fh = Genome::Utility::FileSystem->open_file_for_writing($self->table_file);
    unless ($table_fh) {
        die('Failed to open table file for output: '. $self->table_file);
    }
    print $table_fh "sequences:\t". $total_count ."\n";
    print $table_fh "total length:\t". $total_bp ."\n";
    print $table_fh "masked:\t". $masked_bp ." bp ( ". sprintf("%02f",(($masked_bp / $total_bp ) * 100)) ." %) \n";
    print $table_fh $family_string ."\n";
    $table_fh->close;

    return 1;
}
