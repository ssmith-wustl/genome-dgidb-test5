package Genome::Model::Tools::Annotate::AminoAcidSubstitution;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Annotate::AminoAcidSubstitution {
    is  => 'Genome::Model::Tools::Annotate',
    has => [
        transcript => {
            type     => 'String',
            is_input => 1,
            doc      => "Provide the transcript name.",
        },
	amino_acid_substitution => {
	    type      => 'String',
            is_input => 1,
	    doc       => "Provide the amino acid substitution represented in this format => P2249A.",
	},
	 organism => {
	    type  =>  'String',
	    doc   =>  "Provide the organism either mouse or human; default is human.",
	    is_optional  => 1,
	    default => 'human',
	},
	  version => {
	    type  =>  'String',
	    doc   =>  "Provide the imported annotation version; default for human is 54_36p and for mouse is 54_37g.",
	    is_optional  => 1,
	    default => '54_36p',
	},
	   output => {
	    type  =>  'String',
	    doc   =>  "Provide a file name to write your results to. \".txt\" will be appended to it. Default is to print to stdout.",
	    is_optional  => 1,
	},
	
	],
};

sub help_synopsis { 
    "gmt annotate amino-acid-substitution -transcript ENST00000269305 -amino-acid-substitution S166C"
}

sub help_detail {
    return <<EOS

This tool was designed to identify all posible base changes in a codon that could produce a given amino acid substitution. It will also provide the frame and genomic coordinates of the bases that change.
	
EOS
}

sub execute { 
    
    my $self = shift;
    
    my $transcript = $self->transcript;
    my $amino_acid = $self->amino_acid_substitution;
    my $organism = $self->organism;
    my $version = $self->version;
    if ($organism eq "mouse" && $version eq "54_36p") { $version = "54_37g"; }

    my $TranscriptSequence = Genome::Model::Tools::Annotate::TranscriptSequence->create(transcript => $transcript, organism => $organism, version => $version, no_stdout => "1");
    unless ($TranscriptSequence) { App->error_message("couldn't create a transcript sequence object for $transcript"); return;}
    
    my ($transcript_info) = $TranscriptSequence->execute();
    unless ($transcript_info) { App->error_message("couldn't execute the transcript sequence object for $transcript"); return;}
    
    my @positions = &get_positions ($transcript_info,$transcript);
    unless (@positions) { App->error_message("couldn't extract positions from the transcript sequence object"); return;}

    my $output = $self->output;
    if ($output) {
	open(OUT,">$output.txt") || App->error_message("couldn't open the output file $output.txt") && return;
    }

    my @results;
    my @amino_acid_subs = split(/\,/,$amino_acid);
    for my $nsprotein (@amino_acid_subs) { #nsprotein nonsynonymous protein
	
	my ($taa,$protein_number,$daa) = $nsprotein =~ /^(\D)([\d]+)(\D)$/;
	unless ($taa && $protein_number && $daa) {
	    App->error_message("\n$nsprotein is an invalid format. The amino acid change should be represented in this format => P2249A. $nsprotein will be skipped.\n\n");
	    if ($output) {
		print OUT qq(\n$nsprotein is an invalid format. The amino acid change should be represented in this format => P2249A. $nsprotein will be skipped.\n\n);
	    } 
	    next;
	}
	$taa =~ s/(\D)/\U$1/;
	$daa =~ s/(\D)/\U$1/;
	unless ($taa =~ /[C,H,I,M,S,V,A,G,L,P,T,R,F,Y,W,D,N,E,Q,K]/ && $daa =~ /[C,H,I,M,S,V,A,G,L,P,T,R,F,Y,W,D,N,E,Q,K]/) {
	    App->error_message("\n$nsprotein is an invalid format. The amino acids most be one of twenty found in a protein chain. $nsprotein will be skipped.\n\n");
	    if ($output) {
		print OUT qq(\n$nsprotein is an invalid format. The amino acids most be one of twenty found in a protein chain. $nsprotein will be skipped.\n\n);
	    } 
	    next;
	}

	my ($p1,$p2,$p3,$b1,$b2,$b3) = &get_codon ($transcript_info,$transcript,$protein_number,@positions);
	unless ($p1 && $p2 && $p3 && $b1 && $b2 && $b3) {  
	    App->error_message("\nCouldn't identify the target codon $protein_number.  $nsprotein will be skipped.\n\n");
	    if ($output) {
		print OUT qq(\nCouldn't identify the target codon $protein_number.  $nsprotein will be skipped.\n\n);
	    } 
	    next;
	}
	
	my ($result) = &get_result($p1,$p2,$p3,$b1,$b2,$b3,$transcript,$taa,$protein_number,$daa);
	unless ($result) {
	    App->error_message("\nNo result was found for $nsprotein. $nsprotein will be skipped.\n\n");
	    if ($output) {
		print OUT qq(\nNo result was found for $nsprotein.  $nsprotein will be skipped.\n\n);
	    } 
	    next;
	}
	
	if ($output) {
	    print OUT qq(\n$result\n\n);
	} else {
	    print qq(\n$result\n\n);
	}
	push(@results,$result);
    }
    if ($output) {
	print qq(Your results have been printed in $output.txt\n);
	close OUT;
    }

    return unless @results;
    return 1;

}

sub get_result {

    my @result;

    my ($p1,$p2,$p3,$b1,$b2,$b3,$transcript,$taa,$protein_number,$daa) = @_;

    my $codon = "$b1$b2$b3";
    my $display_id = $transcript;
    my $newcodon = Bio::Seq->new( -display_id => $display_id, -seq => $codon );
    my $aa = $newcodon->translate->seq;
    
    unless ($taa eq $aa) {my $result = "The amino acid $taa input for position doesn\'t match the expected amino acid identified $aa"; return $result; }

    
    my $myCodonTable = Bio::Tools::CodonTable->new();
    my @pcodons = $myCodonTable->revtranslate($daa);
    
    my $all_combo_codons = join ' or ' , @pcodons;
    $all_combo_codons =~ s/([\S\s]+)/\U$1/;
    

    my $line = "A mutation in protien number $protein_number causing a nonsynonymous change from $aa to $daa could occur by changing the codon $codon to $all_combo_codons.\n";
    push (@result,$line);
    

    for my $c (@pcodons) {
	$c =~ s/(\S+)/\U$1/;

	my @line;	

	my ($nb1,$nb2,$nb3) = split(//,$c);
	
	$line = "To get the new amino acid with the codon $c,";
	push (@line,$line);

	my ($d1,$d2,$d3);
	
	unless ($b1 eq $nb1) {
	    $line = "the first frame at $p1 would change from $b1 to $nb1";
	    push (@line,$line);
	    $d1 = 1;
	}
	unless ($b2 eq $nb2) {
	    if ($d1) {
		$line = "and";
		push (@line,$line);
	    }
	    $d2 = 1;
	    $line = "the second frame at $p2 would change from $b2 to $nb2";
	    push (@line,$line);
	}
	unless ($b3 eq $nb3) {
	    if ($d1 || $d2) {
		$line = "and";
		push (@line,$line);
	    }
	    $d3 = 1;
	    $line = "the thrid frame at $p3 would change from $b3 to $nb3";
	    push (@line,$line);
	}
	$line = join ' ' , @line;

	$line = "$line.";
	undef@line;
	push (@result,$line);
    }
    my $result = join "\n" , @result;
    return($result);
}

sub get_positions {

    my ($transcript_info,$transcript) = @_;
    my $strand = $transcript_info->{$transcript}->{-1}->{strand};
    my @positions;
    if ($strand eq "+1") {
	foreach my $pos (sort {$a<=>$b} keys %{$transcript_info->{$transcript}}) {
	    unless ($pos == -1) {push(@positions,$pos);}
	}
    } else {
	foreach my $pos (sort {$b<=>$a} keys %{$transcript_info->{$transcript}}) {
	    unless ($pos == -1) {push(@positions,$pos);}
	}
    }

    return @positions;   
    
}

sub get_codon {

    my ($transcript_info,$transcript,$protein_number,@positions) = @_;
    
    my ($p1,$p2,$p3,$b1,$b2,$b3);
    for my $pos (@positions) {
	
	my ($exon,$region) = split(/\,/,$transcript_info->{$transcript}->{$pos}->{exon});
	my $frame = $transcript_info->{$transcript}->{$pos}->{frame};
	my $aa_n = $transcript_info->{$transcript}->{$pos}->{aa_n};
	my $base = $transcript_info->{$transcript}->{$pos}->{base};
	my ($trans_pos) = $transcript_info->{$transcript}->{$pos}->{trans_pos};
	
	my $codon;

	if ($region eq "cds_exon" && $aa_n eq $protein_number) {
	    
	    if ($frame == 1) {
		$p1 = $pos;
		$b1 = $base;
	    } elsif ($frame == 2) {
		$p2 = $pos;
		$b2 = $base;
	    } elsif ($frame == 3) {
		$p3 = $pos;
		$b3 = $base;
		$codon = "$b1$b2$b3";
	    }

	    if ($codon) {

		return ($p1,$p2,$p3,$b1,$b2,$b3);

	    }
	}
    }
    return;
}

1;

