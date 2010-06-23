package EGAP::Command::GenePredictor::SNAP;

use strict;
use warnings;

use Workflow;

use Bio::SeqIO;
use Bio::Tools::Prediction::Exon;
use Bio::Tools::Prediction::Gene;

use English;
use IO::Dir;
use IPC::Run;
use File::Temp;


class EGAP::Command::GenePredictor::SNAP {
    is  => ['EGAP::Command::GenePredictor'],
    has => [
            hmm_file => {
                         is          => 'SCALAR',
                         doc         => 'SNAP HMM (model) file'
                        },
           ],
};

operation_io EGAP::Command::GenePredictor::SNAP {
    input  => [ 'hmm_file', 'fasta_file' ],
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

    
    my ($snap_stdout, $snap_stderr);

    my $temp_fh       = File::Temp->new();
    my $temp_filename = $temp_fh->filename();

    close($temp_fh);

    my @features = ();
    
    my @cmd = (
	       'snap',
	       '-quiet',
	       $self->hmm_file(),
	       $self->fasta_file(),
	       );
    eval {
        
        IPC::Run::run(
                      \@cmd,
		      \undef,
                      '>',
                      $temp_filename,
                      '2>',
                      \$snap_stderr, 
		      ) || die $CHILD_ERROR;
	  
      };
    
    if ($EVAL_ERROR) {
        die "Failed to exec snap: $EVAL_ERROR";
    }

    my $snap_fh = IO::File->new();
    
    $snap_fh->open($temp_filename)
        or die "Can't open '$temp_filename': $OS_ERROR";
    
    my %exons = ( );

    my $current_seq_id;
    
    while (my $line = <$snap_fh>) {

	chomp $line;

        if ($line =~ /^>(.+)$/) {
            $current_seq_id = $1;
        }
        
	else {

            my (
                $label,
                $begin,
                $end,
                $strand,
                $score,
                $five_prime_overhang,
                $three_prime_overhang,
                $frame,
                $group
            ) = split /\t/, $line;

            my $feature = Bio::SeqFeature::Generic->new(
                -seq_id     => $current_seq_id,
                -start      => $begin,
                -end        => $end,
                -primary    => $label,
                -source_tag => 'SNAP',
                -score      => $score,
            );
            
	    push @{$exons{$group}}, $feature;
            
        }
        
    }
    
    foreach my $prediction (keys %exons) {
	
	my ($strand, $start, $end);
	
	my @exons =  sort { $a->start <=> $b->start } @{$exons{$prediction}};
	    
        $start = $exons[0]->start();
        $end   = $exons[$#exons]->end(); 
	
	my $gene = Bio::Tools::Prediction::Gene->new(
						     -seq_id       => $exons[0]->seq_id,
						     -start        => $start,
						     -end          => $end,
						     -strand       => $strand,
						     -source_tag   => $exons[0]->source_tag(),
                                                     -tag          => { 'Sequence' => $prediction },
                                                 );

        if (@exons > 1) {
            
            unless (
                    $exons[0]->primary_tag() eq 'Einit' or 
                    $exons[$#exons]->primary_tag() eq 'Einit'
                ) {
		
                $gene->add_tag_value('start_not_found' => 1);
                
            }
            
            unless (
                    $exons[0]->primary_tag() eq 'Eterm' or
                    $exons[$#exons]->primary_tag() eq 'Eterm'
                ) {
                
                $gene->add_tag_value('end_not_found' => 1);
                
            }

        }
    	
	foreach my $e (@exons){
	    
	    my $exon = Bio::Tools::Prediction::Exon->new(
							 -seq_id       => $e->seq_id(),
							 -start        => $e->start(),
							 -end          => $e->end(),
							 -strand       => $e->strand(),
							 -score        => $e->score(),
							 -source_tag   => $e->source_tag(),
                                                     );
	    
	    $gene->add_exon($exon);
	    
	    $exon->add_tag_value('Sequence' => $gene->get_tag_values('Sequence'));
            
	    $exon->primary_tag('Exon');
	    
	}

        push @features, $gene;

    }
    
    $self->bio_seq_feature(\@features);
           
    return 1;
    
}

1;
