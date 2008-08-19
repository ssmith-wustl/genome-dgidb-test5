#$Id$

package PAP::Command::BlastP;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;
use Bio::SearchIO;
use Bio::SeqFeature::Generic;
use Bio::Annotation::Collection;
use Bio::Annotation::SimpleValue;
use File::Temp qw/ tempfile /;
use IPC::Run;

use English;


class PAP::Command::BlastP {
    is  => ['PAP::Command'],
    has => [
        fasta_file      => { 
                            is          => 'SCALAR', 
                            doc         => 'fasta file name',
                           },
        bio_seq_feature => { 
                            is          => 'ARRAY',  
                            is_optional => 1,
                            doc         => 'array of Bio::Seq::Feature' 
                           },
    ],
};

operation PAP::Command::BlastP {
    input  => [ 'fasta_file'     ],
    output => [ 'bio_seq_feature'],
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


    my $fasta_file  = $self->fasta_file();

    $self->status_message( "Running Blastp" );
 
    #yup!
    my ($blastp_out, $blastp_err);
    my $bacterial_nr = '/gscmnt/temp110/analysis/blast_db/gsc_bacterial/bacterial_nr/bacterial_nr';
    my ($th,$tmpout) = tempfile( "PAP-blastpXXXXXX", SUFFIX => '.blastp');
    my @blastp_command = (
                          'blastp',
                          $bacterial_nr,
                          $fasta_file,
                          "-o", "$tmpout",
                          "E=1e-10",
                          "V=1",
                          "B=50",
                         );

    IPC::Run::run(
                  \@blastp_command,
                  \undef,
                  '>',
                  \$blastp_out,
                  '2>',
                  \$blastp_err,
                 );

    # parse output file
    $self->parse_blast_results($tmpout);

    #Tranlate
    $self->bio_seq_feature([]);

}

=head1 parse_blast_results()

This will be a fun and stressful function for parsing the blastp output!

=cut

sub parse_blast_results
{
    my $self = shift;
    my $results = shift;
    my $bsio = new Bio::SearchIO(-format => 'blast',
                                 -file   => $results,
                                );
    # makeAce does this:
    # desc=`blastParseHGMI <blastoutput> | head -1`
    # does a grep for ***NONE***/hypothetical
    # then puts header in  fof file?
    my $feat;    
    $feat = new Bio::SeqFeature::Generic();
    print "Parsing output\n";
RES:    while( my $r = $bsio->next_result() )
    {
        while( my $hit = $r->next_hit )
        {
            while( my $hsp = $hit->next_hsp )
            {
                my $gene = $r->query_name;
                $feat->seq_id($gene);
                my $hname = $hit->name;
                # junk out of blastParseHGMI...
                my $score   = $hsp->score;
                my $evalue  = $hsp->evalue;
                my $pctid   = sprintf("%.1f",$hsp->percent_identity);
                my $qstart  = $hsp->start('query');
                my $qend    = $hsp->end('query');
                my $sstart  = $hsp->start('subject');
                my $send    = $hsp->end('subject');
                my $description = $hit->description;
                # need to check thru the description if the hit name is
                # hypothetical.  not sure if it is hypothetical for one
                # species if it will be for all?
                my $stats = join("\t",
                                 $score,$evalue,
                                 $pctid,
                                 $qstart,$qend,
                                 $sstart,$send );
                my $short_desc = $description;
                $short_desc =~ s/>.*//;
                if($short_desc =~ /hypothetical/ix)  # this should really be fixed
                {
                    print "is hypothetical\n";
                    print $short_desc, "\n";
                    last RES; # only the first top hit
                }
                else 
                {
                    # do the features here.
                    my $col = new Bio::Annotation::Collection;
                    my $sv = new Bio::Annotation::SimpleValue(
                                     -value => "Stats: $stats TopHit: $hname"
                                                             );
                    #$feat->add_Annotation("Brief_identification", "Stats: $stats TopHit: $hname");
                    $col->add_Annotation("Brief_identification", $sv);
                    $feat->annotation($col);

                    print "added in $gene, with $stats hit $hname\n";
                }

            }
        }
    }

    # creates output like Sequence "sequencename"\nBrief_identification "Stats: " something " TopHit: "something"

    # product id part, see geneNaming.pl...
    my $col = $self->gene_naming($results,$feat);
    $feat->annotation($col);
    my @features;
    push(@features,$feat);
    $self->bio_seq_feature( \@features );
     
    # debug stuff
    my $ref = $self->bio_seq_feature();
    print $#{$ref},"!!!!\n";
    print $feat->seq_id(),"!\n";
    return 1;
}

sub gene_naming
{
    my $self = shift;
    my $blastoutput = shift;
    my $sf = shift;
    # product id part, see geneNaming.pl...
    # if no hits, then ProductID "Predicted Protein"
    # if one hit, check if id/coverage >= 80, if not, just mark
    # as a hypothetical protein
    # else need to check a few things (conserved, matches a swissprot protein),
    #  or there is a similarity to something else... 
    my $bsio = new Bio::SearchIO(-format => 'blast',
                                 -file   => $blastoutput,
                                );

    my $collection = new Bio::Annotation::Collection;
    my $res = $bsio->next_result();
    my $hit = $res->next_hit();
    if(defined($hit))
    {
        # check if %id/%coverage are both >= 80
        # if desc =~ /fragment|homolog|hypothetical|like|predicted|probable|putative|related|similar|synthetic|unknown|unnamed/
        # mark as conserved hypothetical protein
        my $hsp = $hit->next_hsp();
        my $pctid = sprintf("%.1f",$hsp->percent_identity());
        #my $cov = $hsp->match() / $hsp->length('total');
        #if($pctid
        if($pctid >= 80)
        {
            if($hit->description =~ /fragment|homolog|hypothetical|like|predicted|probable|putative|related|similar|synthetic|unknown|unnamed/x)
            {
                # Product_ID "Conserved Hypothetical Protein"
                my $sv = new Bio::Annotation::SimpleValue(
                               -value => "Conserved Hypothetical Protein");
                $collection->add_Annotation("Product_ID", $sv);
            }
            elsif($hit->description =~ /^>sp/x)
            {
                # swiss prot?
                # Product_ID $hit->description, db link???
                my $sv = new Bio::Annotation::SimpleValue(
                               -value => $hit->description . "\t" . $hit->description);
                $collection->add_Annotation("Product_ID", $sv);
                # actually, should add a dblink here too.
            }
            else
            {
                # clean up description:
                #           $splitLine[1] =~ s/\[.*\]//;
                #            $splitLine[1] =~ s/\w+\|.+\|//;
                my $desc = $hit->description;
                $desc =~ s/\[.*\]//x;
                $desc =~ s/\w+\|.+\|//;
                # Product_ID "Hypothetical Protein similar to $hit->description
                my $sv = new Bio::Annotation::SimpleValue(
                               -value => "Hypothetical Protein similar to " . $desc);
                $collection->add_Annotation("Product_ID", $sv);
            }

        }
        else
        {
            # Product_ID "Hypothetical Protein"
            my $sv = new Bio::Annotation::SimpleValue(
                           -value => "Hypothetical Protein");
            $collection->add_Annotation("Product_ID", $sv);
        }

    }
    else # 'count' is 0, no hits to bact nr
    {
        my $sv = new Bio::Annotation::SimpleValue(
                         -value => "Predicted Protein");
        $sf->add_Annotation("Product_ID", "Predicted Protein");
    }
    # need to generate 'count'

    return $collection;
}

 
1;
