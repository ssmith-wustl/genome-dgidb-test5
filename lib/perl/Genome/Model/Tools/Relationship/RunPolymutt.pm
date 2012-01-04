package Genome::Model::Tools::Relationship::RunPolymutt;

use strict;
use warnings;
use Data::Dumper;
use Genome;           
use Genome::Info::IUB;
use POSIX;
our $VERSION = '0.01';
use Cwd;
use File::Basename;
use File::Path;

class Genome::Model::Tools::Relationship::RunPolymutt {
    is => 'Command',
    has_optional_input => [
    denovo => {
        is=>'Text',
        is_optional=>1,
        default=>0,
    },
    output_vcf => {
        is=>'Text',
        is_optional=>0,
        is_output=>1,
    },
    glf_index => {
        is=>'Text',
        is_optional=>0,
    },
    dat_file => {
        is=>'Text',
        is_optional=>0,
    },
    ped_file => {
        is=>'Text',
        is_optional=>0,
    },
    threads => {
        is=>'Text',
        is_optional=>1,
        default=>4,
    },
    ],
    has_param => [
    lsf_resource => {
        is => 'Text',
        default => "-R 'span[hosts=1] rusage[mem=1000] -n 4'",
    },
    lsf_queue => {
        is => 'Text',
        default => 'long',
    },
    ],


};

sub help_brief {
    "simulates reads and outputs a name sorted bam suitable for import into Genome::Model"
}

sub help_detail {
}
#/gscuser/dlarson/src/polymutt.0.01/bin/polymutt -p 20000492.ped -d 20000492.dat -g 20000492.glfindex --minMapQuality 1 --nthreads 4 --vcf 20000492.standard.vcf
sub execute {
    $DB::single=1;
    my $self=shift;
    my $polymutt_cmd= "/gscuser/dlarson/src/polymutt.0.01/bin/polymutt";
    my $ped_file = $self->ped_file;
    my $dat_file = $self->dat_file;
    my $glf_index= $self->glf_index;
    my $threads = $self->threads;
    my $output_vcf = $self->output_vcf;
    my $cmd = $polymutt_cmd;
     $cmd .= " -p $ped_file";
     $cmd .= " -d $dat_file";
     $cmd .= " -g $glf_index";
     $cmd .= " --minMapQuality 1";
     $cmd .= " --nthreads $threads";
     $cmd .= " --vcf $output_vcf";
    if($self->denovo) {
        $cmd .= " --denovo";
    }


    my $rv = Genome::Sys->shellcmd(cmd=> $cmd);
    if($rv != 1) {
        return;
    }
    return 1;
}

1;
