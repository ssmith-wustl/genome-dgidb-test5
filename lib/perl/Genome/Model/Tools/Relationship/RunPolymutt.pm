package Genome::Model::Tools::Relationship::RunPolymutt;

use strict;
use warnings;
use Data::Dumper;
use Genome;           
use Genome::Info::IUB;
use POSIX;
our $DEFAULT_VERSION = '0.02';
use Cwd;
use File::Basename;
use File::Path;

class Genome::Model::Tools::Relationship::RunPolymutt {
    is => 'Command',
    has_optional_input => [
        version => {
            is => 'Text',
            default => $DEFAULT_VERSION,
            doc => "Version to use",
        },
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
        bgzip => {
            is_optional=>1,
            default=>1,
            doc=>'set this to 0 if you prefer uncompressed',
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

my %VERSIONS = (
    '0.02' => '/usr/bin/polymutt0.02',
);

sub path_for_version {
    my $class = shift;
    my $version = shift || $DEFAULT_VERSION;

    unless(exists $VERSIONS{$version}) {
        $class->error_message('No path found for polymutt version ' . $version);
        die $class->error_message;
    }

    return $VERSIONS{$version};
}

sub default_version {
    my $class = shift;

    unless(exists $VERSIONS{$DEFAULT_VERSION}) {
        $class->error_message('Default polymutt version (' . $DEFAULT_VERSION . ') is invalid.');
        die $class->error_message;
    }

    return $DEFAULT_VERSION;
}

sub available_versions {
    return keys(%VERSIONS);
}

#/gscuser/dlarson/src/polymutt.0.01/bin/polymutt -p 20000492.ped -d 20000492.dat -g 20000492.glfindex --minMapQuality 1 --nthreads 4 --vcf 20000492.standard.vcf
sub execute {
    $DB::single=1;
    my $self=shift;
    my $polymutt_cmd= $self->path_for_version($self->version);
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
    if($self->bgzip) {
        my $cmd = "bgzip $output_vcf";
        Genome::Sys->shellcmd(cmd=>$cmd); 
    }

    return 1;
}

1;
