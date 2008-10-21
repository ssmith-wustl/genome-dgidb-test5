package Genome::Model::Tools::Hgmi::MkPredictionModels;

use strict;
use warnings;

use Genome;
use Command;
use Carp;
use IPC::Run qw/ run /;

UR::Object::Type->define(
                         class_name => __PACKAGE__,
                         is => 'Command',
                         has => [
                                 'locus_tag_prefix' => {is => 'String',
                                                        doc => "HGMI Locus Tag Prefix" },
                                 'mk_script' => {is => 'String',
                                        doc => "",
                                        default => "/gsc/scripts/gsc/annotation/mkBAPgenemod",
                                        is_optional => 1 }, 
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
This tool depends on mkBAPgenemod.bsh.
EOS
}


sub execute
{
    my $self = shift;

    # do IPC::Run stuff and just execute mkBAPgenemod.bsh

    my @genemod_command = (
                           '/gsc/bin/bash',
                           $self->mk_script,
                           $self->locus_tag_prefix
                           );
    my ($genemod_out,$genemod_err);
    IPC::Run::run(
                  \@genemod_command,
                  \undef,
                  '>',
                  \$genemod_out,
                  '2>',
                  \$genemod_err,
                  ) || croak "mkBAPgenemod failure : $!";

    return 1;
}


1;

# $Id$
