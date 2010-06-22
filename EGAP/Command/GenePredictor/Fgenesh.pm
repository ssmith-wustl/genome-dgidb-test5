package EGAP::Command::GenePredictor::Fgenesh;

use strict;
use warnings;

use Workflow;

use Bio::SeqIO;
use Bio::Tools::Run::Fgenesh;

class EGAP::Command::GenePredictor::Fgenesh {
    is => ['EGAP::Command::GenePredictor'],
    has => [
            parameter_file => { is => 'SCALAR', doc => 'absolute path to the parameter (model) file for this fasta' },
    ],
};

operation_io EGAP::Command::GenePredictor::Fgenesh {
    input  => [ 'parameter_file', 'fasta_file' ],
    output => [ 'bio_seq_feature' ]
};

sub sub_command_sort_position { 10 }

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
    

    my @features = ( );

    ##FIXME: Bio::Tools::Run::Fgenesh needs to be cluebatted into accepting fasta files as input
    my $seqio = Bio::SeqIO->new(-format => 'Fasta', -file => $self->fasta_file());
    my $seq   = $seqio->next_seq();
    
    my $factory = Bio::Tools::Run::Fgenesh->new(
                                                -program => 'fgenesh',
                                                -param   =>  $self->parameter_file(),
                                               );

    my $parser = $factory->run($seq);

    while (my $gene = $parser->next_prediction()) {

        my @exons = $gene->exons();

        foreach my $exon (@exons) {

            my $start = $exon->start();
            my $end   = $exon->end();

            if ($start > $end) {

                ($start, $end) = ($end, $start);

                $exon->start($start);
                $exon->end($end);
                
            }

        }

        @exons = sort { $a->start() <=> $b->start() } @exons;

        my $new_gene = Bio::Tools::Prediction::Gene->new(
                                                         -seq_id     => $gene->seq_id(),
                                                         -start      => $exons[0]->start(),
                                                         -end        => $exons[$#exons]->end(),
                                                         -strand     => $exons[0]->strand(),
                                                         -source_tag => $exons[0]->source_tag(),
                                                     );

        if (@exons > 1) {

            unless (
                    $exons[0]->primary_tag() eq 'InitialExon' or 
                    $exons[$#exons]->primary_tag() eq 'InitialExon'
                   ) {
                
                $new_gene->add_tag_value('start_not_found' => 1);
                
            }

            unless (
                    $exons[0]->primary_tag() eq 'TerminalExon' or 
                    $exons[$#exons]->primary_tag() eq 'TerminalExon'
                   ) {
                
                $new_gene->add_tag_value('end_not_found' => 1);
                
            }
            
            
        }
        
        foreach my $exon (@exons) {
            $new_gene->add_exon($exon);
        }

        push @features, $new_gene;
        
    }
    
    $self->bio_seq_feature(\@features);
    
    return 1;
    
}

1;
