package PAP::Command::BlastP;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

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

    my $version;#=???
    my $file1;#=???
    my $dir;#=???
    my $3;#=???
    my $blastp_dir = "$dir/Blastp/Version_$version/$file1";

    unless (-d  $blastp_dir){
        $self->error_message("blast_p dir doesn't exist");
        return 0;
    }
    
    $self->status_message( "Running Blastp" );
 
    chdir $blastp_dir;
    
 unless( -e $3){
  system("ln -s $dir/Gene_merging/Version_$version/$file1/$3 .");
}
 my $numTotal =`array_shatter $3`;
 my $remainder = $numTotal%1000;
 my $numMax = $numTotal-$remainder;
 my $num0 = 1;
 my $num1= $num0+999;

 while ($num1 <= $numMax ){
   bsub -J 'blastp_array['$num0-$num1']' -q long -n 2 -R 'span[hosts=1]' -o blastp.out -e blastp.err "blastp /gscmnt/temp110/analysis/blast_db/gsc_bacterial/bacterial_nr/bacterial_nr \$LSB_JOBINDEX.fasta -o \$LSB_JOBINDEX.blastp E=1e-10 V=1 B=50"
  $num0= $num1+1;
  $num1= $num0+999;
}

#Tranlate
$self->bio_seq_feature([]);

}
 
1;
