package Genome::Model::Tools::PrepareNextgenAce;

use Genome;
use Command;
use GSCApp;
use strict;
use Data::Dumper;
use File::Basename;
use warnings;

class Genome::Model::Tools::PrepareNextgenAce 
{
    is => 'Command',
    has => 
    [
        basedir => {
          type => 'String',
          doc => "directory w/ all the projects",                                              
        },
        project_dir => {
          type => 'String',
          doc => "individual project dir", 
          is_optional => 1,                                             
        },
        fof => {
          type => 'String',
          doc => "fof of project-dirs (relative path ok)",
          is_optional => 1,                                              
        },
        ref_seq_padding => {
          type => 'String',
          doc => "padding of coordinates for ref_sequence",
          is_optional => 1,
        },
        clean_dir => {
          type => 'String',
          doc => "cleans-dir",
          is_optional => 1,
        },
    ],
};

############################################################

sub help_brief {   
    return;
}

sub help_synopsis { 
    return;
}

sub help_detail {
    return <<EOS
    usage: prepare_nextgen_ace --basedir <full_path> --project-dir <specific_dir> --fof < list of project-dirs> 
EOS
}

############################################################

sub execute {
    my $self = shift;
$DB::single = 1;
    my $basedir = $self->basedir;
    my $p_dir = $self->project_dir;
    my $fof = $self->fof;
    my $padding = $self->ref_seq_padding;
    my $clean = $self->clean_dir;
    my $build = '46_36h';
    my @projects;
    
    %ARGV = ();
    
    App->init();

    unless($basedir){
        $basedir = `pwd`;
        chomp $basedir;
    }else{
        chdir $basedir or die "couldn't cd to ". $basedir;
    }

    unless($padding){
        $padding = 300;
    }

    if($fof){
        open F,  $fof or die "can't open fof $fof";
        while(<F>){
            chomp;
            push @projects, $_;
        }
        close F;
    }

    push @projects, $p_dir if($p_dir);

    for my $project_string (@projects){
        chdir $basedir or die "can't cd to $basedir";
        chdir $project_string or die "can't cd to $project_string";
        if($clean){
            for("\\rm -r edit_dir", "\\rm -r chromat_dir", "\\rm phdball_dir/*"){
                print "$_\n";
                system($_);
            }
        }

        my ($chrom, $start);# = split(/_/, $project_string);
        print $project_string, "\n";
        ($chrom, $start) = $project_string =~ /.*\/(\d+)_(\d+)/;#split(/_/, $project_string);
        ($chrom, $start) = $project_string =~ /.?(\d+)_(\d+)/ unless (defined $chrom && defined $start);
        $project_string = $chrom.'_'.$start;
        my $expecting ="1_34744774";
        if($start =~ /\D/ ){
            die "error in project_name_structure... $expecting";
        }

        $chrom =~ s/chr//ig;
        if($chrom =~ /x|y/i){
            $chrom = uc $chrom;
        }

        my $pad_start = $start - $padding;
        my $pad_end = $start + $padding;
        $pad_start =1 if $pad_start <= 0;
        my $offset = $pad_end - $pad_start;

    #check for input files 
        my ($fastq) = glob("*readlist");
        unless($fastq){
            warn "no fastq files in dir";
        }

        #setup directory structure
    my $edit_dir = 'edit_dir';
    my $solexa_dir = 'solexa_dir';
    my $sff_dir = 'sff_dir';
    my $phdball_dir = 'phdball_dir';
    my $chromat_dir = 'chromat_dir'; 
    my $phd_dir = 'phd_dir';

    for(($edit_dir, $solexa_dir, $sff_dir, $phdball_dir,$chromat_dir,$phd_dir)){
        next if -d $_;
        mkdir $_ or die "can't mkdir $_";
    }

    #get ref_seqeunce
        my $root_name = $project_string;
        my $root_name_fasta= "$root_name.fasta";
        my $command;
        unless(-e "$chromat_dir/$root_name.c1"){
            my $seq_name =  "NCBI-human-build36-chrom$chrom";
            my $item = GSC::Sequence::Item->get(sequence_item_name => $seq_name);
            unless($item){
                die "can't get Sequence::Item w/ name $seq_name";
            }

            my $seq =substr($item->sequence_base_string,$pad_start, $offset);
            GSC::Sequence::BaseString->unload;
            open F, ">$root_name_fasta" or die;
            print F ">$root_name_fasta\n";
            print F "$seq\n";

            $command = "consensus_raid -dir . -fasta $root_name_fasta -piece-type c -quality-value 30 -root-name $root_name";
            print "$command\n";
            system($command);

            $command = "mv $root_name_fasta $edit_dir";
            print $command . "\n";
            system($command);
        }

    my $flag;
        if(!-e "$edit_dir/solexa.fof" or -z "$edit_dir/solexa.fof"){
            $command  = "/gscuser/sabbott/bin/solexa_fetch_read.pl --fastq $fastq --overwrite";
            print $command . "\n";
            system($command);
            $flag++;
        }

    my $ace= "$project_string.ace";
        chdir $edit_dir or die;
        unless(-e "$ace"){
            $command = "fasta2Ace.perl $root_name_fasta"; 
            print $command . "\n";
            system($command);

        }

    #do solexa stuff
    my $ace1= "$project_string.ace.1";

        if(!-e "$ace1" or -z "$ace1" or $flag){
            $command = "addSolexaReads2 $ace solexa.fof " .  $root_name_fasta;
            print $command . "\n";
            system($command);

            &fix_ace("$ace1", $pad_start, $root_name_fasta, [$padding, $padding]);
        }else{
            print "skipping $project_string\n";
        }

    }
    return 1;
}

sub fix_ace{
    my ($file, $roi_start,$contig, @array_start_stop ) =@_;

    my $switch;
    my @file;

    open ACE, $file or return;
    while(<ACE>){
       push @file, $_ ;
    }

    system("mv $file $file.bak");

    open F, ">$file" or die;

    for( @file){
        print F $_ ;
    }

    for(@array_start_stop){
        my $start = $_->[0];
        my $stop= $_->[1];

        print F "\nCT{\n".
        "$contig comment SABBOTT $start $stop 080428:160524\n".
        "COMMENT{\n".
        "Please be a validated SNP\n".    
        "C}\n".
        "}\n";
    }

    print F "\nCT{\n".
    "$contig startNumberingConsensus consed 1 1 080428:160524\n".
    "$roi_start\n".    
    "}\n";

    close F;

}

1;
