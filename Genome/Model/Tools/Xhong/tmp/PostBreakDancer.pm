package Genome::Model::Tools::Xhong::PostBreakDancer;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Xhong::PostBreakDancer {
    is => 'Command',
    has => [
    genome_name => { 
        type => 'String',
        is_optional => 0,
        doc => "common name of the sample",
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
    
    my $user = $ENV{USER}; 
    my $cfg_name = $dir . "/$genome_name.cfg";
    unless(-e $cfg_name) {
	$self->status_message("Unable to find $cfg_name and quit now");
	return;
    }
    
    
    my $username = getlogin;
    
    #launching blade jobs
    print `bsub -N -u $user\@genome.wustl.edu -R 'select[type==LINUX64] [mem>8000] rusage[mem=8000]' -M 8000000  -J '$genome_name BreakDancer novoalign' '~kchen/MPrelease/BreakDancer/novoRealign.pl $cfg_file'`
	
    return 1;

}


1;

sub help_brief {
    "Helps run BreakDancer by making symlinks and starting jobs"
}

sub help_detail {
    <<'HELP';
This script helps runs BreakDancer. It uses a somatic model to locate the tumor and normal bam files and then launches the appropriate downstream BreakDancer commands. It does not run novoalign and does not assist in checking for chimeric lanes.
HELP
}
