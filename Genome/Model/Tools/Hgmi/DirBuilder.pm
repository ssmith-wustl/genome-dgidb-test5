package Genome::Model::Tools::Hgmi::DirBuilder;

use strict;
use warnings;

use Genome;
use Command;
use Carp;
use File::Slurp;
use DateTime;
use List::MoreUtils qw/ uniq /;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is         => 'Command',
    has        => [
        'path' => {
            is  => 'String',
            doc => "direcotry path"
        },
        'org_dirname' => {
            is  => 'String',
            doc => "organism abbreviated name"
        },
        'assembly_version_name' => {
            is  => 'String',
            doc => "complete assembly name and version"
        },
        'assembly_version' => {
            is  => 'String',
            doc => "analysis version"
        },
        'pipe_version' => {
            is  => 'String',
            doc => "pipeline version"
        },
        'cell_type' => {
            is  => 'String',
            doc => "[BACTERIA|EUKARYOTES]"
        },
    ],

);

sub help_brief
{
    "tool for creating the directory structure for HGMI/Annotation projects";
}

sub help_synopsis
{
    my $self = shift;
    return <<"EOS"
Creates the standard annotation/analysis directory structure.
EOS

}

sub help_detail
{
    my $self = shift;
    return <<"EOS"
This tool creates the standard directory structure for a project.
EOS

}

sub execute
{
    my $self = shift;

    my $date;
    my $dt  = DateTime->now;
    my $ymd = $dt->ymd('');
    $date = $ymd;
    my @moredirs = ();

    if ( $self->cell_type =~ /BACTERIA/ )
    {
        @moredirs = (
            'Ensembl_pipeline', 'Gene_predictions',
            'Gene_merging',     'Genbank_submission',
            'Sequence',         'Rfam',
            'Repeats',          'Kegg',
            'Cog',              'Interpro',
            'psortB',           'Blastp',
            'BAP'
        );    #Bacteria
    }
    else
    {
        @moredirs = (
            'Acedb',              'Ensembl_pipeline',
            'Gene_predictions',   'Gene_merging',
            'Genbank_submission', 'Sequence',
            'gff_files',          'Gene_merging',
            'Repeats',            'Kegg',
            'Cog',                'Interpro',
            'GAP'
        );    #Eukaryotes
    }

    # it looks like there's a bunch of extra
    # filepath variables that are built here
    my $dirpatha = undef;
    my $dirpath  = undef;
    $dirpatha = $self->path . "/"
        . $self->org_dirname . "/"
        . $self->assembly_version_name;
    $dirpath = $dirpatha . "/" . $self->assembly_version;
    my $newdir       = $self->path . "/" . $self->org_dirname;
    my $assembly_dir = $self->assembly_version_name;             # why?
    my $version      = $self->pipe_version;                      # again, why?

    foreach my $file (@moredirs)
    {
        my @cmd = ();

        unless ( -e $newdir )
        {
            push( @cmd, $newdir );
        }

        unless ( -e $dirpatha )
        {
            push( @cmd, $dirpatha );
        }

        unless ( -e $dirpath )
        {
            push( @cmd, $dirpath );
        }

        my $dirpathfile = $dirpath . "/" . $file;
        unless ( -e $dirpathfile ) { push( @cmd, $dirpathfile ); }
        my $dirpfversion = $dirpath . "/" . $file . "/" . $version;
        unless ( -e $dirpfversion ) { push( @cmd, $dirpfversion ); }
        my $dirpfScripts = $dirpath . "/" . $file . "/Scripts";

        if ( $file =~ 'Ensembl_pipeline' )
        {

            unless ( -e $dirpfScripts ) { push @cmd, $dirpfScripts; }
            my $dirpfvSequence
                = $dirpath . "/" . $file . "/" . $version . "/Sequence";
            unless ( -e $dirpfvSequence ) { push @cmd, $dirpfvSequence; }
            my $dirpfvDumps
                = $dirpath . "/" . $file . "/" . $version . "/Dumps";
            unless ( -e $dirpfvDumps ) { push @cmd, $dirpfvDumps; }
        }
        if ( $file =~ 'Genbank_submission' )
        {
            unless ( -e $dirpfScripts ) { push @cmd, qq{$dirpfScripts}; }
            my $dirpfvDraft
                = qq{$dirpath/$file/$version/Draft_submission_files};
            unless ( -e $dirpfvDraft ) { push @cmd, qq{$dirpfvDraft}; }
            my $dirpfvAnnotated
                = qq{$dirpath/$file/$version/Annotated_submission};
            unless ( -e $dirpfvAnnotated ) {
                push @cmd, qq{$dirpfvAnnotated};
            }
        }
        if ( $file =~ 'Gene_predictions' )
        {
            unless ( -e $dirpfScripts ) { push @cmd, qq{$dirpfScripts}; }
            my $dirpfvEannot = qq{$dirpath/$file/$version/Eannot};
            unless ( -e $dirpfvEannot ) { push @cmd, qq{$dirpfvEannot}; }
            my $dirpfvGenewise = qq{$dirpath/$file/$version/Genewise};
            unless ( -e $dirpfvGenewise ) { push @cmd, qq{$dirpfvGenewise}; }
            my $dirpfvGenemark = qq{$dirpath/$file/$version/Genemark};
            unless ( -e $dirpfvGenemark ) { push @cmd, qq{$dirpfvGenemark}; }
            my $dirpfvGlimmer2 = qq{$dirpath/$file/$version/Glimmer2};
            unless ( -e $dirpfvGlimmer2 ) { push @cmd, qq{$dirpfvGlimmer2}; }
            my $dirpfvGlimmer3 = qq{$dirpath/$file/$version/Glimmer3};
            unless ( -e $dirpfvGlimmer3 ) { push @cmd, qq{$dirpfvGlimmer3}; }
            my $dirpfvSnap = qq{$dirpath/$file/$version/Snap};
            unless ( -e $dirpfvSnap ) { push @cmd, qq{$dirpfvSnap}; }
            my $dirpfvGenscan = qq{$dirpath/$file/$version/Genscan};
            unless ( -e $dirpfvGenscan ) { push @cmd, qq{$dirpfvGenscan}; }
            my $dirpfvFgenesh = qq{$dirpath/$file/$version/Fgenesh};
            unless ( -e $dirpfvFgenesh ) { push @cmd, qq{$dirpfvFgenesh}; }
            my $dirpfvGenefinder = qq{$dirpath/$file/$version/Genefinder};

            unless ( -e $dirpfvGenefinder ) {
                push @cmd, qq{$dirpfvGenefinder};
            }
        }
        if ( $file =~ 'Gene_merging' )
        {
            unless ( -e $dirpfScripts ) { push @cmd, qq{$dirpfScripts}; }
            my $dirpfvHybrid = qq{$dirpath/$file/$version/Hybrid};
            unless ( -e $dirpfvHybrid ) { push @cmd, qq{$dirpfvHybrid}; }
            my $dirpfvHIntergenic
                = qq{$dirpath/$file/$version/Hybrid/intergenic};
            unless ( -e $dirpfvHIntergenic )
            {
                push @cmd, qq{$dirpfvHIntergenic};
            }
        }
        if ( $file =~ 'Repeats' )
        {
            unless ( -e $dirpfScripts ) { push @cmd, qq{$dirpfScripts}; }
            my $dirpfvRECON = qq{$dirpath/$file/$version/RECON};
            unless ( -e $dirpfvRECON ) { push @cmd, qq{$dirpfvRECON}; }
            my $dirpfvRQC = qq{$dirpath/$file/$version/RECON/QC};
            unless ( -e $dirpfvRQC ) { push @cmd, qq{$dirpfvRQC}; }
            my $dirpfvRRepeatmasker
                = qq{$dirpath/$file/$version/RECON/RepeatMasker};
            unless ( -e $dirpfvRRepeatmasker )
            {
                push @cmd, qq{$dirpfvRRepeatmasker};
            }
        }
        if ( $file =~ 'Sequence' )
        {
            my $dirpfMasked = qq{$dirpath/$file/Masked};
            unless ( -e $dirpfMasked ) { push @cmd, qq{$dirpfMasked}; }
            my $dirpfUnmasked = qq{$dirpath/$file/Unmasked};
            unless ( -e $dirpfUnmasked ) { push @cmd, qq{$dirpfUnmasked}; }
        }
        if ( $file =~ 'Acedb' )
        {
            unless ( -e $dirpfScripts ) { push @cmd, qq{$dirpfScripts}; }
            my $dirpfvwgf = qq{$dirpath/$file/$version/wgf};
            unless ( -e $dirpfvwgf ) { push @cmd, qq{$dirpfvwgf}; }
            my $dirpfvwspec = qq{$dirpath/$file/$version/wspec};
            unless ( -e $dirpfvwspec ) { push @cmd, qq{$dirpfvwspec}; }
            my $dirpfvDatabase = qq{$dirpath/$file/$version/database};
            unless ( -e $dirpfvDatabase ) { push @cmd, qq{$dirpfvDatabase}; }
            my $dirpfvGff = qq{$dirpath/$file/$version/Gff_files};
            unless ( -e $dirpfvGff ) { push @cmd, qq{$dirpfvGff}; }
        }
        if ( $file =~ 'Rfam' )
        {
            unless ( -e $dirpfScripts ) { push @cmd, qq{$dirpfScripts}; }

        }
        if ( $file =~ 'Kegg' )
        {
            unless ( -e $dirpfScripts ) { push @cmd, qq{$dirpfScripts}; }

            my $dirpfvGenemark = qq{$dirpath/$file/$version/Genemark};
            unless ( -e $dirpfvGenemark ) { push @cmd, qq{$dirpfvGenemark}; }
            my $dirpfvGlimmer2 = qq{$dirpath/$file/$version/Glimmer2};
            unless ( -e $dirpfvGlimmer2 ) { push @cmd, qq{$dirpfvGlimmer2}; }
            my $dirpfvGlimmer3 = qq{$dirpath/$file/$version/Glimmer3};
            unless ( -e $dirpfvGlimmer3 ) { push @cmd, qq{$dirpfvGlimmer3}; }
            my $dirpfvHybrid = qq{$dirpath/$file/$version/Hybrid};
            unless ( -e $dirpfvHybrid ) { push @cmd, qq{$dirpfvHybrid}; }
        }
        if ( $file =~ 'Cog' )
        {
            unless ( -e $dirpfScripts ) { push @cmd, qq{$dirpfScripts}; }

            my $dirpfvGenemark = qq{$dirpath/$file/$version/Genemark};
            unless ( -e $dirpfvGenemark ) { push @cmd, qq{$dirpfvGenemark}; }
            my $dirpfvGlimmer2 = qq{$dirpath/$file/$version/Glimmer2};
            unless ( -e $dirpfvGlimmer2 ) { push @cmd, qq{$dirpfvGlimmer2}; }
            my $dirpfvGlimmer3 = qq{$dirpath/$file/$version/Glimmer3};
            unless ( -e $dirpfvGlimmer3 ) { push @cmd, qq{$dirpfvGlimmer3}; }
            my $dirpfvHybrid = qq{$dirpath/$file/$version/Hybrid};
            unless ( -e $dirpfvHybrid ) { push @cmd, qq{$dirpfvHybrid}; }
        }
        if ( $file =~ 'Interpro' )
        {
            unless ( -e $dirpfScripts ) { push @cmd, qq{$dirpfScripts}; }

            my $dirpfvGenemark = qq{$dirpath/$file/$version/Genemark};
            unless ( -e $dirpfvGenemark ) { push @cmd, qq{$dirpfvGenemark}; }
            my $dirpfvGlimmer2 = qq{$dirpath/$file/$version/Glimmer2};
            unless ( -e $dirpfvGlimmer2 ) { push @cmd, qq{$dirpfvGlimmer2}; }
            my $dirpfvGlimmer3 = qq{$dirpath/$file/$version/Glimmer3};
            unless ( -e $dirpfvGlimmer3 ) { push @cmd, qq{$dirpfvGlimmer3}; }
            my $dirpfvHybrid = qq{$dirpath/$file/$version/Hybrid};
            unless ( -e $dirpfvHybrid ) { push @cmd, qq{$dirpfvHybrid}; }

        }
        if ( $file =~ 'psortB' )
        {
            unless ( -e $dirpfScripts ) { push @cmd, qq{$dirpfScripts}; }

            my $dirpfvGenemark = qq{$dirpath/$file/$version/Genemark};
            unless ( -e $dirpfvGenemark ) { push @cmd, qq{$dirpfvGenemark}; }
            my $dirpfvGlimmer2 = qq{$dirpath/$file/$version/Glimmer2};
            unless ( -e $dirpfvGlimmer2 ) { push @cmd, qq{$dirpfvGlimmer2}; }
            my $dirpfvGlimmer3 = qq{$dirpath/$file/$version/Glimmer3};
            unless ( -e $dirpfvGlimmer3 ) { push @cmd, qq{$dirpfvGlimmer3}; }
            my $dirpfvHybrid = qq{$dirpath/$file/$version/Hybrid};
            unless ( -e $dirpfvHybrid ) { push @cmd, qq{$dirpfvHybrid}; }
        }
        if ( $file =~ 'Blastp' )
        {
            unless ( -e $dirpfScripts ) { push @cmd, qq{$dirpfScripts}; }

            my $dirpfvHybrid = qq{$dirpath/$file/$version/Hybrid};
            unless ( -e $dirpfvHybrid ) { push @cmd, qq{$dirpfvHybrid}; }
        }
        if ( $file =~ 'BAP' )
        {
            my $dirpfvSequence = qq{$dirpath/$file/$version/Sequence};
            unless ( -e $dirpfvSequence ) { push @cmd, qq{$dirpfvSequence}; }
            my $dirpfvDumps = qq{$dirpath/$file/$version/Dumps};
            unless ( -e $dirpfvDumps ) { push @cmd, qq{$dirpfvDumps}; }
        }
        if ( $file =~ 'GAP' )
        {
            my $dirpfvSequence = qq{$dirpath/$file/$version/Sequence};
            unless ( -e $dirpfvSequence ) { push @cmd, qq{$dirpfvSequence}; }
            my $dirpfvDumps = qq{$dirpath/$file/$version/Dumps};
            unless ( -e $dirpfvDumps ) { push @cmd, qq{$dirpfvDumps}; }
        }

        @cmd = uniq @cmd;    # make sure there are now duplicates.

        foreach my $cmd (@cmd)
        {
            mkdir $cmd or croak "can't mkdir $cmd : $!\n";
        }
        my $readme = $newdir . "/"
            . $assembly_dir
            . "/README_"
            . $self->assembly_version_name;
        my $message = " This file was created on $date for "
            . $self->org_dirname
            . "using assembly: "
            . $self->assembly_version_name . "\n";
        write_file( $readme, ($message) );

    }

    return 1;
}

1;

# $Id$
