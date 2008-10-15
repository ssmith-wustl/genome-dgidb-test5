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
need to put help synopsis here.
EOS

}

sub help_detail
{
    my $self = shift;
    return <<"EOS"
need to put help detail here.
EOS
}


sub execute
{
    my $self = shift;

    # do IPC::Run stuff and just execute mkBAPgenemod.bsh

    return 1;
}


1;
