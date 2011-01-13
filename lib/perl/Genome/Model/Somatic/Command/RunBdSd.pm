package Genome::Model::Somatic::Command::RunBdSd;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Somatic::Command::RunBdSd {
    is => 'Command',
    has => [
    build_id => { 
        type => 'String',
        is_optional => 0,
        doc => "build id of the somatic build to process",
    },
    dir => { 
        type => 'String',
        is_optional => 0,
        doc => "directory to drop the BreakDancer files into",
    },
    force => {
        type => 'Boolean',
        is_optional => 1,
        default => 0,
        doc => "whether or not to launch blade jobs regardless of symlinks etc." ,
    },
    ]
};


sub execute {
    my $self=shift;
    $DB::single = 1;
    my $force = $self->force;
    #check the passed directory
    my $dir = $self->dir;
    unless(-d $dir) {
        $self->error_message("$dir is not a directory");
        return;
    }
    
    $self->error_message( "$dir" );
    #retrieve the build et al
    my $build_id = $self->build_id;

    my $build = Genome::Model::Build->get($build_id);
    unless(defined($build)) {
        $self->error_message("Unable to find build $build_id");
        return unless $force;;
    }
    my $model = $build->model;
    unless(defined($model)) {
        $self->error_message("Somehow this build does not have a model");
        return unless $force;
    }
    unless($model->type_name eq 'somatic') {
        $self->error_message("This build must be a somatic pipeline build");
        return unless $force;
    }

    #retrieve the tumor bam
    my $tumor_bam = $build->tumor_build->whole_rmdup_bam_file;
    unless($tumor_bam) {
        $self->error_message("Couldn't determine tumor bam file from somatic model");
        return unless $force;
    }

    if(-z $tumor_bam) {
        $self->error_message("$tumor_bam is of size 0 or does not exist");
        return unless $force;
    }

    #check bam is indexed
    my $tumor_bam_bai = "$tumor_bam.bai";
    if(-z $tumor_bam_bai) {
        $self->error_message("$tumor_bam_bai is of size 0 or does not exist");
        return unless $force;
    }
    
    my $tumor_bam_link_name = $dir . "/tumor.bam";
    my $tumor_bai_link_name = $tumor_bam_link_name . ".bai";
    
    unless(symlink $tumor_bam, $tumor_bam_link_name) {
        $self->error_message("Unable to symlink tumor bam");
        return unless $force;
    }
            
        
    unless(symlink "$tumor_bam.bai", $tumor_bai_link_name) {
        $self->error_message("Unable to symlink tumor bam index");
        return unless $force;
    }
    
    my $normal_bam = $build->normal_build->whole_rmdup_bam_file;
    my $normal_bam_bai = "$normal_bam.bai";

    unless($normal_bam) {
        $self->error_message("Couldn't determine normal bam file from somatic model");
        return unless $force;
    }
    if(-z $normal_bam) {
        $self->error_message("$normal_bam is of size 0 or does not exist");
        return unless $force;
    }
    if(-z $normal_bam_bai) {
        $self->error_message("$normal_bam_bai is of size 0 or does not exist");
        return unless $force;
    }

    my $normal_bam_link_name = $dir . "/normal.bam";
    my $normal_bai_link_name = $normal_bam_link_name . ".bai";

    unless(symlink $normal_bam, $normal_bam_link_name) {
        $self->error_message("Unable to symlink normal bam");
        return unless $force;
    }
    unless(symlink $normal_bam_bai, $normal_bai_link_name) {
        $self->error_message("Unable to symlink normal bam index");
        return unless $force;
    }


    my $genome_name = $build->tumor_build->model->subject->source_common_name;   #this should work
    unless($genome_name) {
        $self->error_message("Unable to retrieve sample name from tumor build");
        return unless $force;
    }
    my $user = $ENV{USER}; 
    my $cfg_name = $dir . "/$genome_name.cfg";
    chdir $dir;
    unless(-e $cfg_name) {
        #run bam2cfg
        $self->status_message("Running bam2cfg");
        print `pwd`;
        $self->status_message("$dir");
        print `bsub -N -u $user\@genome.wustl.edu -q short -J '$genome_name bam2cfg' -R 'select[type==LINUX64]' '~kchen/MPrelease/BreakDancer/bam2cfg.pl -g -h $tumor_bam_link_name $normal_bam_link_name > $cfg_name'`;
        sleep(300); #wait for this to finish since running is via system is not working

        $self->status_message("Bringing up png files for viewing of distributions. If you are on blade make sure you are able to open an X window (ie have modified permissions with xhost");
        print `eog $dir/*.png`;
    }
    else {
        $self->status_message("Found $cfg_name and proceeding with this file");
    }

    system('pwd');
    #print stats from .cfg file regarding chimeric reads and std/mean ratio
    $self->status_message("Chimeric Read %\tstd/mean ratio");
    my $cfgfh = new IO::File $cfg_name,"r";
    while (my $line = $cfgfh->getline) {
        my ($rg,$pf,$map,$rl,$lib,$num,$low,$up,$mean,$std,$sw,$flag,$exe) = split /\t/,$line;
        my ($chimer) = $flag =~ m/\)32\((\d+\.\d+)%\)/;
        $chimer ||= 0;
        $mean =~ s/^mean:(.+)$/$1/; 
        $std =~ s/^std:(.+)$/$1/; 
        my $ratio = $std/$mean;
        print "$rg\t$chimer\t$ratio";
        if ($chimer > 5.0) {
            print "\tCHECK CHIMER";
        }
        if ($ratio > 0.3) {
            print "\tCHECK STD/MEAN RATIO";
        }
        print "\n";
    }        

    #prompt to proceed
    print "Proceed with launching of blade jobs? [y/N]\n";
    my $return = <STDIN>;

    unless($return =~ /^(y|yes)$/i) {
        return;
    }
    
    my $username = getlogin;
    my $ctx_file = "$dir/$genome_name.ctx";

    #launching blade jobs
    
    # CTX job
    my $jobid=`bsub -N -u $user\@genome.wustl.edu -R 'select[type==LINUX64]' -J '$genome_name CTX' 'breakdancer_max -t -q 10 -d $ctx_file $cfg_name > $ctx_file'`;
    $jobid=~/<(\d+)>/;
    $jobid= $1;
    print "$jobid\n";
    my $jobid2=`bsub -N -u $user\@genome.wustl.edu -R 'select[type==LINUX64 && mem>8000] rusage[mem=8000]' -M 8000000 -w 'ended($jobid)' -J '$genome_name SV6' '~kchen/MPrelease/BreakDancer/novoRealign.pl $cfg_name'`;
    $jobid2=~/<(\d+)>/;
    $jobid2= $1;
    print "$jobid2\n";
    my $novo_ctx_file="$dir/$genome_name.novo.ctx";
    my $novo_cfg_file="$dir/$genome_name.novo.cfg";
    print `bsub -N -u $user\@genome.wustl.edu -R 'select[type==LINUX64 && mem>8000] rusage[mem=8000]' -M 8000000 -w 'ended($jobid2)' -J '$genome_name SV7' 'breakdancer_max -t $novo_cfg_file > $novo_ctx_file'`;
    
    #submit per chromosome bams
    
   for my $chr (1..22,"X","Y") { 
       print `bsub -N -u $user\@genome.wustl.edu -R 'select[type==LINUX64]' -J '$genome_name chr$chr' 'breakdancer_max -o $chr -q 10 -f $cfg_name > $genome_name.chr$chr.sv'`;
   } 

    #submit squaredancer job
    my $jobid3=`bsub -N -u $user\@genome.wustl.edu -J '$genome_name SD' -e SD.err -o SD.out -R 'select[type==LINUX64 && mem>8000] rusage [mem=8000]' -M 8000000 -q long '/gsc/scripts/opt/genome/current/pipeline/lib/perl/Genome/Model/Tools/Sv/SquareDancer.pl -l normal tumor.bam normal.bam'`;
    $jobid3=~/<(\d+)>/;
    $jobid3= $1;
    print "$jobid3\n";
    
    return 1;

}


1;

sub help_brief {
    "Helps run BreakDancer and SquareDancerby making symlinks and starting jobs"
}

sub help_detail {
    <<'HELP';
This script runs lastest vertion of BreakDancer (CPP) and Squaredancer (perl). It uses a somatic model to locate the tumor and normal bam files and then launches the appropriate downstream BreakDancer commands. It does not run novoalign and does not assist in checking for chimeric lanes, which need to manually done.
HELP
}
