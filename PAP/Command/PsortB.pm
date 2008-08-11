package PAP::Command::PsortB;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;
use File::Temp qw/ tempdir /;
use IPC::Run;
use Cwd;

use English;


class PAP::Command::PsortB {
    is  => ['PAP::Command'],
    has => [
        fasta_file      => { 
                            is  => 'SCALAR', 
                            doc => 'fasta file name' ,
                           },
        gram_stain      => {
                            is  => 'SCALAR',
                            doc => 'gram stain (positive/negative)',
                           },
        bio_seq_feature => { 
                            is          => 'ARRAY', 
                            is_optional => 1,
                            doc         => 'array of Bio::Seq::Feature', 
                           },
    ],
};

operation PAP::Command::PsortB {
    input  => [ 'fasta_file', 'gram_stain' ],
    output => [ 'bio_seq_feature' ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Run psort-b";
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
    my $gram_stain  = $self->gram_stain();

    if ($gram_stain eq 'positive') {
        $gram_stain = '-p';
    }
    elsif ($gram_stain eq 'negative') {
        $gram_stain = '-n';
    }
    else {
        die "gram stain should be positive or negative, not '$gram_stain'";
    }

    my @psortb_command = (
                          'psort-b',
                          $gram_stain, 
                          '-o terse',
                         );

    # do tmp dir, shatter files,
    my $current_dir = getcwd;
    my $tmpdir = tempdir("psortbXXXXXX"); # CLEANUP => 1???
    $self->working_directory($current_dir);
    chdir($current_dir . "/" . $tmpdir);
    my $max_chunks = $self->shatter_fasta();
    # psort-b each sub-fasta
    my @psortbdata;
    foreach my $i (1..$max_chunks)
    {
        my ($psortb_out, $psortb_err);

        my $psortb_file = $i . ".fa";
        push(@psortb_command,$psortb_file);
        IPC::Run::run(
                       \@psortb_command,
                       \undef,
                       '>',
                       \$psortb_out,
                       '2>',
                       \$psortb_err,
                     );
        pop(@psortb_command);
        my @tmpdata = read_file($psortb_out);
        push(@psortbdata,@tmpdata);
    }
    # parse output
    # turn that into bioseq features
    # clean up sub-fastas/temp dir.
    # fertig!
    $self->parse_psortb_terse(\@psortbdata);
    $self->bio_seq_feature([]);

}

sub shatter_fasta {
    my $self = shift;
    my $seqfile = $self->fasta_file();
    my $s = new Bio::SeqIO(-file => $seqfile, -format => 'fasta');
    my $idx = 1;
    while(my $seq = $s->next_seq()) {
        my $ofile = $idx . ".fa"; 
        my $so = new Bio::SeqIO(-file => ">$ofile", -format => 'fasta');
    }
    return $idx;
}

sub parse_psortb_terse
{
    my $self = shift;
    my $data = shift;
    foreach my $line (@$data)
    {
        # split on tabs,
        # should get gene name, classification, and score
        # skip score < 7.5
        my ($gene, $class, $score) = split(/\t/,$line);
        next unless $score >= 7.5;
    }

}
 
1;

# $Id$
