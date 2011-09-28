package Genome::Model::Tools::ImportAnnotation::SplitFiles;

use strict;
use warnings;
use Genome;
use IO::File;
use File::Slurp;
use File::Basename;
use File::Copy qw/ mv cp /;
use Text::CSV_XS;
use POSIX qw/ floor /;
use IPC::Run;
use Carp;

class Genome::Model::Tools::ImportAnnotation::SplitFiles {
    is  => 'Command',
    has => [
        workdir => {
            is  => "Text",
            doc => "directory to split files in",
        },
    ],
};

sub sub_command_sort_position {12}

sub help_brief
{
    "split up files for file-based data sources";
}

sub help_synopsis
{
    return <<EOS
    gmt import-annotation split-files --workdir <path to annotation dumps>
EOS
}

sub help_detail
{
    return <<EOS
This command is used for splitting up the files dumped for the filesystem-based
data sources.
EOS
}

sub execute
{
    my $self    = shift;
    my $workdir = $self->workdir;


    #unless($workdir =~ /\/$/)
    #{
    #    $self->workdir($workdir."/");
    #    $workdir = $self->workdir;
    #}
    # split up genes by gene_id
    #$DB::single = 1;
    $self->split_files( 0, "genes.csv" );

    # split up transcripts by chromosome
    $self->split_transcripts();

    # split up transcript sub structs by every 1000 transcript ids
    $self->split_files_tss();

    # split up proteins by transcript id
    $self->split_files( 1, "proteins.csv" );

    # create source_data dir
    unless ( -d $workdir . "/source_data" )
    {
        mkdir( $workdir . "/source_data" );
    }

    my ($stdout,$stderr);
    # copy transcripts to source_data, move others to source_data
    IPC::Run::run(
        ['cp',$self->workdir.'/transcripts.csv',
         $self->workdir."/source_data", ],
        \undef,
        '>', \$stdout,
        '2>', \$stderr,
        ) or croak "problem copying transcripts $!\n$stderr";

    # move the rest.
    IPC::Run::run(
        ['mv',$self->workdir.'/genes.csv',
         $self->workdir.'/proteins.csv',
         $self->workdir.'/transcript_sub_structures.csv',
         $self->workdir.'/source_data',],
        \undef,
        '>', \$stdout,
        '2>', \$stderr,
        ) or croak "problem moving other datafiles $!\n$stderr";

    return 1;
}

sub split_files_tss
{
    my $self      = shift;
    my $outputdir = $self->workdir;
    my $tssdir    = $outputdir . "/transcript_sub_structure_tree";
    unless ( -d $tssdir )
    {
        mkdir($tssdir);
    }

    my $fh = IO::File->new( $outputdir . "/transcript_sub_structures.csv" );
    my $csv = Text::CSV_XS->new( { sep_char => "\t" } );
    while (<$fh>)
    {
        $csv->parse($_);
        my @sub_fields   = $csv->fields();
        my $sub_trans_id = $sub_fields[1];
        my $thousand     = int( $sub_trans_id / 1000 );
        $thousand .= '000';
        my $path = $tssdir . "/" . $thousand . "/" . $sub_trans_id . ".csv";
        unless ( -d $tssdir . "/" . $thousand )
        {
            mkdir( $tssdir . "/" . $thousand );
        }
        write_file( $path, { append => 1 }, $_ );
    }
    $fh->close;
    return 1;
}

sub split_files
{
    my $self    = shift;
    my $scol    = shift;
    my $file    = shift;
    my $workdir = $self->workdir;
    my $outdir  = $file;
    $outdir =~ s/\.csv$//x;

    unless ( -d $workdir . "/" . $outdir )
    {
        mkdir( $workdir . "/" . $outdir );
    }

    my $csv = Text::CSV_XS->new( { sep_char => "\t" } );
    my $fh = IO::File->new( $workdir . "/" . $file );
    while (<$fh>)
    {
        $csv->parse($_);
        my @fields = $csv->fields();
        my $id     = floor( $fields[$scol] / 1000 );

        my $file_name
            = $workdir . "/" . $outdir . "/" . $outdir . "_" . $id . ".csv";
        write_file( $file_name, { append => 1 }, $_ );
    }
    $fh->close;

    return 1;
}

sub split_transcripts
{
    my $self          = shift;
    my $transcriptdir = $self->workdir . "/transcripts";

    unless ( -d $transcriptdir )
    {
        mkdir($transcriptdir);
    }

    my ($stdout, $stderr);
    my $retval;
    # run sort on the transcripts.csv file

    IPC::Run::run(
        ['sort', '-n', '-k3,9', '-o', 
         $self->workdir.'/transcripts.csv.sorted', 
         $self->workdir."/transcripts.csv" ],
        \undef,
        '>',
        \$stdout,
        '2>',
        \$stderr,
        ) or croak "sorting transcripts.csv $!\n$stderr";

    IPC::Run::run(
        [ 'cp', $self->workdir.'/transcripts.csv.sorted',
          $self->workdir."/transcripts.csv",],
        \undef,
        '>',
        \$stdout,
        '2>',
        \$stderr,
        ) or croak "copying sorted transcripts.csv $!\n$stderr";

    my $fh = IO::File->new( $self->workdir . "/transcripts.csv" );
    my $csv = Text::CSV_XS->new( { sep_char => "\t" } );
    while (<$fh>)
    {

        #
        $csv->parse($_);
        my @fields = $csv->fields();
        my $chr    = $fields[8];
        write_file( $transcriptdir . "/transcripts_" . $chr . ".csv",
            { append => 1 }, $_ );

    }
    $fh->close;
    return 1;
}

1;

# $Id$
