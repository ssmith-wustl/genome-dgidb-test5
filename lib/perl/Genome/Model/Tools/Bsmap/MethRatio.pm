package Genome::Model::Tools::Bsmap::MethRatio;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Bsmap::MethRatio {
    is => 'Command',
    has => [
        bam_file => {
            is => 'Text',
            doc => 'The bam file to do the counting on (must be a product of bsmap alignment',
        },
        output_file => {
            is => 'Text',
            doc => 'Where to output the methyl counts',
        },
        reference => {
            is => 'Text',
            doc => '36, 37, or a path to the reference fasta',
        }
    ],
    has_optional => [
        chromosome => {
            is => 'Text',
            doc => 'process only this chromosome',
        },
        output_zeros => {
            is => 'Boolean',
            doc => 'report loci with zero methylation ratios',
            default => 1,
        },

# other options not exposed:
#   -u, --unique          process only unique mappings/pairs.
#   -p, --pair            process only properly paired mappings.
#   -q, --quiet           don't print progress on stderr.
#   -r, --remove-duplicate
#                         remove duplicated reads.
#   -t N, --trim-fillin=N
#                         trim N end-repairing fill-in nucleotides. [default: 2]
#   -g, --combine-CpG     combine CpG methylaion ratios on both strands.
#   -m FOLD, --min-depth=FOLD
#                         report loci with sequencing depth>=FOLD. [default: 1]

    ],
};

sub execute {
    my $self = shift;
    my $fasta;

    if ($self->reference eq "36") {
        my $reference_build_fasta_object = Genome::Model::Build::ReferenceSequence->get(name => "NCBI-human-build36");
        $fasta = $reference_build_fasta_object->data_directory . "/all_sequences.fa";
    }
    elsif ($self->reference eq "37") {
        my $reference_build_fasta_object = Genome::Model::Build::ReferenceSequence->get(name => "GRCh37-lite-build37");
        $fasta = $reference_build_fasta_object->data_directory . "/all_sequences.fa";
    } else {
        if( -s $self->reference){
            $fasta = $self->reference;
        } else {
            $self->error_message('reference must be either "36", "37", or the path to a valid reference file');
            return 0;
        }
    }

    my $cmd = "python /gscuser/cmiller/usr/src/bsmap-2.6/methratio.py";
    $cmd .= " -o ". $self->output_file;
    $cmd .= " -d " . $fasta;
    if($self->output_zeros){
        $cmd .= " -z";
    }
    if($self->chromosome){
        $cmd .= " -c" . $self->chromosome;
    }
    $cmd .= " " . $self->bam_file;
    
    $self->error_message("Running command: $cmd");

    my $return = Genome::Sys->shellcmd(
        cmd => "$cmd",
        );
    unless($return) {
        $self->error_message("Failed to execute: Returned $return");
        die $self->error_message;
    }    

    return 1;
}

1;
