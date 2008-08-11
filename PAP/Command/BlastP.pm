package PAP::Command::BlastP;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;
use Bio::SearchIO;
use Bio::SeqFeature::Generic;
use File::Temp qw/ tempfile /;

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
    my ($th,$tmpout) = tempfile( "PAP-blastpXXXXXX", SUFFIX => '.blastp');
    my @blastp_command = (
                          'blastp',
                          $bacterial_nr,
                          $fasta_file,
                          "-o $tmpout",
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

sub parse_blast_results
{
    my $self = shift;
    my $results = shift;
    my $bsio = new Bio::SearchIO(-format => 'blast',
                                 -file   => $results,
                                );


    return 1;
}

 
1;
