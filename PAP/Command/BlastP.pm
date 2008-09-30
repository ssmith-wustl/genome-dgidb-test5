#$Id$

package PAP::Command::BlastP;

use strict;
use warnings;

use Workflow;

use Bio::Annotation::DBLink;
use Bio::Seq;
use Bio::SeqIO;
use Bio::SearchIO;
use Bio::SeqFeature::Generic;

use English;
use File::Temp;
use IPC::Run;


class PAP::Command::BlastP {
    is  => ['PAP::Command'],
    has => [
        fasta_file      => { 
                            is  => 'SCALAR', 
                            doc => 'fasta file name',
                           },
        blast_report => {
                         is          => 'SCALAR',
                         is_optional => 1,
                         doc         => 'instance of File::Temp pointing to raw blast output'
                        },
        bio_seq_feature => { 
                            is          => 'ARRAY',  
                            is_optional => 1,
                            doc         => 'array of Bio::Seq::Feature' 
                           },
    ],
};

operation PAP::Command::BlastP {
    input        => [ 'fasta_file'     ],
    output       => [ 'bio_seq_feature'],
    lsf_queue    => 'long',
    lsf_resource => 'rusage[tmp=100]';
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Run blastp";
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

 
    my ($blastp_out, $blastp_err);

    ##FIXME:  This should not be hardcoded.  At least not here.
    my $bacterial_nr = '/gscmnt/temp110/analysis/blast_db/gsc_bacterial/bacterial_nr/bacterial_nr';

    my $fasta_file = $self->fasta_file();
    
    my $temp_fh    = File::Temp->new();
    my $temp_fn    = $temp_fh->filename();

    $self->blast_report($temp_fh);
     
    my @blastp_command = (
                          'blastp',
                          $bacterial_nr,
                          $fasta_file,
                          '-o',
                          $temp_fn,
                          'E=1e-10',
                          'V=1',
                          'B=50',
                         );

    IPC::Run::run(
                  \@blastp_command,
                  \undef,
                  '>',
                  \$blastp_out,
                  '2>',
                  \$blastp_err,
              ) || die "blastp failed: $CHILD_ERROR";
    
    $self->parse_result();

    ## Be Kind, Rewind.  Somebody will surely assume we've done this,
    ## so let's not surprise them.
    $temp_fh->seek(0, SEEK_SET);

    return 1;

}

sub parse_result {
    
    my $self  = shift;
 
    
    ## According to the docs for Bio::Root::IO,
    ## -noclose should prevent the filehandle
    ## from being closed when $searchio gets
    ## garbage collected.  
    my $searchio = Bio::SearchIO->new(
                                      -format  => 'blast',
                                      -fh      => $self->blast_report(),
                                      -noclose => 1, 
                                  );

    my @features = ( );
    
    ## There should be one result per query sequence.
  RESULT: while (my $result = $searchio->next_result()) {

        my $query_name = $result->query_name();
        
        my $feature = Bio::SeqFeature::Generic->new(-display_name => $query_name);

        my $protein_category = 'Predicted Protein';
        
        my $hit = $result->next_hit();

        if (defined($hit)) {
            
            my $hit_name        = $hit->name();
            my $hit_accession   = $hit->accession();
            my $hit_description = $hit->description();
            
            if($hit_description !~ /hypothetical/i) {
                
                my $hsp = $hit->next_hsp();
                
                unless (defined($hsp)) { next RESULT; }

                if (defined($hsp)) {
                    
                    my $score       = $hsp->score;
                    my $evalue      = $hsp->evalue;
                    my $pctid       = sprintf("%.1f",$hsp->percent_identity());
                    my $qstart      = $hsp->start('query');
                    my $qend        = $hsp->end('query');
                    my $sstart      = $hsp->start('subject');
                    my $send        = $hsp->end('subject');

                    if ($pctid >= 80) {
                        
                        if ($hit_description =~ /fragment|homolog|hypothetical|like|predicted|probable|putative|related|similar|synthetic|unknown|unnamed/) {

                            $protein_category = 'Conserved Hypothetical Protein';
                            
                        }
                        else {

                            my $analogue = $hit_description;

                            $analogue =~ s/\[.*\]//x;
                            $analogue =~ s/\w+\|.+\|//;

                            $protein_category = "Hypothetical Protein similar to $analogue";

                        }
                        
                    }

                    $feature->add_tag_value('blastp_bit_score', $score);
                    $feature->add_tag_value('blastp_evalue', $evalue);
                    $feature->add_tag_value('blastp_percent_identical', $pctid);
                    $feature->add_tag_value('blastp_query_start', $qstart);
                    $feature->add_tag_value('blastp_query_end', $qend);
                    $feature->add_tag_value('blastp_subject_start', $sstart);
                    $feature->add_tag_value('blastp_subject_end', $send);
                    $feature->add_tag_value('blastp_hit_name', $hit_name);
                    
                    my $dblink = Bio::Annotation::DBLink->new(
                                                              -database   => 'GenBank',
                                                              -primary_id => $hit_accession,
                                                          );
                    
                    $feature->annotation->add_Annotation('dblink', $dblink);
                    
                }
                
            }

        }
        
        $feature->add_tag_value('blastp_category', => 'protein_category');
        
        push @features, $feature;
        
    }
    
    $self->bio_seq_feature(\@features);
    
}
 
1;
