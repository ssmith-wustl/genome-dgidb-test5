#$Id$

package PAP::Command::BlastP;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;
use Bio::SearchIO;
use Bio::SeqFeature::Generic;
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
    
    while( my $r = $bsio->next_result() )
    {
        while( my $hit = $r->next_hit )
        {
            while( my $hsp = $hit->next_hsp )
            {
                my $gene = $r->query_name;
                my $hname = $hit->name;
                # junk out of blastParseHGMI...
                my $score   = $hsp->score;
                my $evalue  = $hsp->score;
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
            }
        }
    }

    # creates output like Sequence "sequencename"\nBrief_identification "Stats: " something " TopHit: "something"

    # product id part, see geneNaming.pl...
    $self->gene_naming($results);

    return 1;
}

sub gene_naming
{
    my $self = shift;
    my $blastoutput = shift;
    # product id part, see geneNaming.pl...
    # if no hits, then ProductID "Predicted Protein"
    # if one hit, check if id/coverage >= 80, if not, just mark
    # as a hypothetical protein
    # else need to check a few things (conserved, matches a swissprot protein),
    #  or there is a similarity to something else... 
    return 1;
}

 
1;
