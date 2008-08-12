#$Id$

package PAP::Command::KEGGScan;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;
use Bio::SeqFeature::Generic;
use File::Slurp;
use File::Temp qw/ tempdir tempfile /;
use Cwd;
use IPC::Run;

use English;


class PAP::Command::KEGGScan {
    is  => ['PAP::Command'],
    has => [
        fasta_file      => { 
                            is => 'SCALAR', 
                            doc => 'fasta file name'            
                           },
        bio_seq_feature => { 
                            is          => 'ARRAY',  
                            is_optional => 1,
                            doc         => 'array of Bio::Seq::Feature' 
                           },
        working_directory => {
                              is => 'SCALAR',
                              doc => 'working directory',
                              is_optional => 1,
                             },
    ],
};

operation PAP::Command::KEGGScan {
    input  => [ 'fasta_file'      ],
    output => [ 'bio_seq_feature' ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Run KEGGscan";
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
    # this incarnation of keggscan should be deployed.
    my @keggscan_command = (
                            '/gsc/scripts/gsc/annotation/KEGGscan_KO.new.070125',
                           );
    my ($kegg_stdout, $kegg_stderr) = ("test.out","test.err");
    # should create tempdir, move into it.
    my $tmpdir = tempdir("keggscanXXXXXX"); # CLEANUP=>1???
    my $current_dir = getcwd;
    $self->working_directory($current_dir);
    chdir($current_dir . "/" . $tmpdir);
    $self->create_kscfg();

    IPC::Run::run(
                   \@keggscan_command,
                   \undef,
                   '>',
                   \$kegg_stdout,
                   '2>',
                   \$kegg_stderr,
                 );

    # cleanup, move out of temp dir
    $self->parse_kegg();
    $self->cleanup();
    chdir($current_dir);

    return 1;

}

=head1 create_kscfg

KEGGscan needs a configuration file with these items:

 SpeciesName\t"species"
 QueryFastaPath\t"path/to/peptides"
 SubjectFastaPath\t"path/to/KEGGrelease"
 QuerySeqType\t"CONTIG"
 Queue\t"long"
 BladeLoad\t"40"
 KeggRelease\t"RELEASE-41"

=cut

sub create_kscfg
{
    my $self = shift;

# need to output
    my $species = undef;
    my $subjectpath = "/gscmnt/233/analysis/sequence_analysis/species_independant/jmartin/hgm.website/KEGG/KEGG_release_41/genes.v41.faa";
    my $queryfasta = $self->fasta_file;
    unless($queryfasta =~ /^\//x)
    {
        $queryfasta = $self->working_directory() . "/". $queryfasta;
    }
    my $bladeload = 1;
    my $keggrel = "RELEASE-41";

    my @config = (
                  qq(SpeciesName\t"default"\n),
                  qq(QueryFastaPath\t"$queryfasta"\n),
                  qq(SubjectFastaPath\t"$subjectpath"\n),
                  qq(QuerySeqType\t"CONTIG"\n),
                  qq(Queue\t"long"\n),
                  qq(BladeLoad\t"$bladeload"\n),
                  qq(KeggRelease\t"$keggrel"\n),
                 );
    write_file('KS.cfg', @config);
    return;
}


sub cleanup
{
    my $self = shift;
    # get rid of crap here.
    return;
}

sub parse_kegg
{
    my $self = shift;
    my $keggout;
    my @lines = read_file($keggout);
    chomp;
    my $feat = undef;
    my $a = Bio::Annotation::Collection->new;
    foreach my $l (@lines)
    {
        my ($junk,$gene,$code, $eVal,$junk2,$desc, $junk3,$ko)
            = split(/\t/x,$l);
        $gene =~ s/\(.*//x;
        unless(defined($feat))
        {
            $feat = new Bio::SeqFeature::Generic( -seq_id => $gene );
        }
        $desc =~ s/\(EC .+\)//;  # removing the EC number???
        if($ko eq "none")
        {
            $ko = "";
        }
        # create the bio seq annotation/feature object
        my $keggstring = $code . " " . $eVal . " " . $desc . " " . $ko;
        $feat->add_Annotation("KEGG", $keggstring);
    }
    # put $feat into $self->bio_seq_feature 
    $self->bio_seq_feature( [ $feat ] );

    return;
}
 
1;
