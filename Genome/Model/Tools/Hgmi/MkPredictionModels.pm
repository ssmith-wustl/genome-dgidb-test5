package Genome::Model::Tools::Hgmi::MkPredictionModels;

use strict;
use warnings;

use Genome;
use Command;
use Carp;
use Cwd;
use MGAP::Command::BuildGlimmerInput;
use MGAP::Command::CalculateGcPercent;

UR::Object::Type->define(
                         class_name => __PACKAGE__,
                         is => 'Command',
                         has => [
                                 'locus_tag_prefix' => {is => 'String',
                                                        doc => "HGMI Locus Tag Prefix" },
                                 'fasta_file' => { is => 'String',
                                                    doc => "Fasta file for input" },
                                 'work_directory' => { is => 'String',
                                                       doc => "Working directory",
                                                       is_optional => 1},
                                 'gc' => { is => 'Float',
                                           doc => "GC content percent",
                                           is_optional => 1,  },

]
                         );


sub help_brief
{
    "tool for creating the glimmer and genemark models";
}

sub help_synopsis
{
    my $self = shift;
    return <<"EOS"
For building the glimmer/genemark model files.
EOS

}

sub help_detail
{
    my $self = shift;
    return <<"EOS"
mk-prediction-models creates a de-novo set of glimmer and genemark model files
based on the GC content in the contigs.

EOS
}


sub execute
{
    my $self = shift;

    my $gc_command = MGAP::Command::CalculateGcPercent->create(
                       'fasta_files' => [ $self->fasta_file ],
                        );

    unless($gc_command)
    {
        croak "Failure on calculating GC content";
    }

    my $buildglimmer = MGAP::Command::BuildGlimmerInput->create(
                          'fasta_files' => [ $self->fasta_file ],
                         );

    unless( $buildglimmer )
    {
        croak "Failure on building glimmer models";
    }

    # need to create links to the proper files.

    $gc_command->execute() or croak "can't calculate GC percentage";
    $buildglimmer->execute() or croak "can't build glimmer models";

    # the heu_11*mod files - use the GC percent (rounding up).
    # just take the items off the the buildglimmer when that is
    # successful and create the necessary symlinks.
    # or if necessary copy the files to a more permanent position
    #print "GC content ", $gc_command->gc_percent,"%\n";
    #print "model file ", $buildglimmer->model_file,"\n";
    #print "pwm file ", $buildglimmer->pwm_file,"\n";


    $self->gc(int($gc_command->gc_percent));

    if(!defined($self->work_directory))
    {
        $self->work_directory(getcwd());
    }

    # messy, but works for now.
    my $gmhmmp_dir = "/gscmnt/temp212/info/annotation/gmhmmp_models";
    my $gmhmmp_mod = $gmhmmp_dir . "/heu_11_" . $self->gc . ".mod";
    my $gmhmmp_dest = $self->work_directory ."/heu_11_".$self->gc .".mod";
    symlink($gmhmmp_mod, $gmhmmp_dest) 
        or croak "can't symlink gmhmmp model $gmhmmp_mod to $gmhmmp_dest, $@";
    my $workdir = $self->work_directory;
    my $model = $buildglimmer->model_file;
    my $newmodel = $workdir ."/". $self->locus_tag_prefix . "_gl3.icm";
    my $pwm = $buildglimmer->pwm_file;
    my $newpwm = $workdir ."/". $self->locus_tag_prefix . "_gl3.motif";

    # should check if destination files exist, and create copies before 
    #mv-ing over.
    system("mv $model $newmodel");
    if($@)
    {
        croak "problem copying $model to $newmodel";
    }
    system("mv $pwm $newpwm");

    if($@)
    {
        croak "problem copying $pwm to $newpwm";
    }
    return 1;
}


1;

# $Id$
