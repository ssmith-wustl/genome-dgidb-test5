package Genome::Model::Tools::Hgmi::Hap;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model::Tools::Hgmi::DirBuilder;
use Genome::Model::Tools::Hgmi::CollectSequence;
use Genome::Model::Tools::Hgmi::SequenceName;
use Genome::Model::Tools::Hgmi::MkPredictionModels;
use Genome::Model::Tools::Hgmi::Predict;
use Genome::Model::Tools::Hgmi::Merge;
use Genome::Model::Tools::Hgmi::Finish;
use Genome::Model::Tools::Hgmi::SendToPap;

use Carp;
use English;
use Cwd;
use File::Path qw(mkpath);
use File::Spec;
use YAML qw( LoadFile DumpFile );

# should have a crap load of options.
UR::Object::Type->define(
    class_name => __PACKAGE__,
    is         => 'Command',
    has        => [
        'config' => {
            is  => 'String',
            doc => "YAML file for reading"
        },
        'gen_example' => {
            is          => 'Boolean',
            doc         => "Generate an example yaml config file",
            is_optional => 1
        },
        'internalhash' => {
            is          => 'HashRef',
            doc         => "internal",
            is_optional => 1
        },
        'dev' => {
            is          => 'Boolean',
            doc         => "development flag for testing",
            is_optional => 1
        },
        'skip_core_check' => {
            is          => 'Boolean',
            doc         => "skips core genes check",
            is_optional => 1,
            default     => 0,
        },
        'skip_ber' => {
            is          => 'Boolean',
            doc         => "skips the JCVI product naming tools",
            is_optional => 1,
            default     => 0,
        },
        'skip_protein_annotation' => {
            is          => 'Boolean',
            doc         => "skips running bap_finish, protein annotation and ber",
            is_optional => 1,
            default     => 0,
        },

    ]
);

sub help_brief
{
    "Runs the entire HGMI tools pipeline";
}

sub help_synopsis
{
    my $self = shift;
    return <<"EOS"
For running the entire HGMI tools pipeline.
EOS

}

sub help_detail
{
    my $self = shift;
    return <<"EOS"
For running the entire HGMI tools pipeline.
Takes in a YAML file for configuration parameters and then runs each tool
for the HGMI pipeline.
EOS
}

sub execute
{
    my $self = shift;

    if ( defined( $self->gen_example ) )
    {
        if ( -f $self->config )
        {
            croak "cowardly refusing to overwrite existing file! Hap.pm \n\n";
        }

        $self->build_empty_config();
        return 1;
    }

    if ( -f $self->config )
    {
        $self->internalhash( LoadFile( $self->config ) );
    }
    else
    {

        # blow up...
        my $file = $self->config;
        carp "non-existent file $file Hap.pm\n\n";
        return 0;
    }

    my $config = $self->internalhash;
    if($config->{cell_type} eq 'VIRAL')
    {
        $self->skip_core_check(1);
    }

    # this is where we might drop items for validity
    my $base_path - $config->{path};

    # dir-builder
    my $d = Genome::Model::Tools::Hgmi::DirBuilder->create(
        path                  => $config->{path},
        org_dirname           => $config->{org_dirname},
        assembly_version_name => $config->{assembly_name},
        assembly_version      => $config->{assembly_version},
        pipe_version          => $config->{pipe_version},
        cell_type             => $config->{cell_type}
    );

    if ($d)
    {
        $d->execute() or croak "can't run dir-builder Hap.pm\n\n";
    }
    else
    {
        croak "can't set up dir-builder";
    }

    my $next_dir = $config->{path} . "/"
        . $config->{org_dirname} . "/"
        . $config->{assembly_name} . "/"
        . $config->{assembly_version} . "/"
        . "Sequence/Unmasked";
    chdir($next_dir);

    # collect-sequence
    my $cs = Genome::Model::Tools::Hgmi::CollectSequence->create(
        seq_file_name  => $config->{seq_file_name},
        seq_file_dir   => $config->{seq_file_dir},
        minimum_length => $config->{minimum_length},
    );

    if ($cs)
    {
        $cs->execute() or croak "can't run collect-sequence Hap.pm\n\n";
        
    }
    else
    {
        croak "can't set up collect-sequence Hap.pm\n\n";
    }

    # sequence-name
    my $sn = Genome::Model::Tools::Hgmi::SequenceName->create(
        locus_tag        => $config->{locus_tag},
        fasta            => $cs->new_ctgs_out,
        analysis_version => $config->{pipe_version},
        acedb_version    => $config->{acedb_version},
        project_type     => $config->{project_type},
        path             => $config->{path},
    );

    if ($sn)
    {
        $sn->execute() or croak "can't run sequence-name Hap.pm\n\n";
    }
    else
    {
        croak "can't set up sequence-name";
    }

    # chdir( dir-path/ org-name / assem name,version/ pipe version
    # chdir();
    # mk-prediction-model
    $next_dir = $config->{path} . "/"
        . $config->{org_dirname} . "/"
        . $config->{assembly_name} . "/"
        . $config->{assembly_version} . "/" . "BAP" . "/"
        . $config->{pipe_version}
        . "/Sequence";
    chdir($next_dir);

    my $model = Genome::Model::Tools::Hgmi::MkPredictionModels->create(
        locus_tag  => $config->{locus_tag},
        fasta_file => $sn->new_output,
    );

    if ($model)
    {
        $model->execute() or croak "can't run mk-prediction-model Hap.pm\n\n";
    }
    else
    {
        croak "can't set up mk-prediction-model Hap.pm\n\n";
    }

    $next_dir = $config->{path} . "/"
        . $config->{org_dirname} . "/"
        . $config->{assembly_name} . "/"
        . $config->{assembly_version} . "/" . "BAP" . "/"
        . $config->{pipe_version};
    chdir($next_dir);

    my $predict = Genome::Model::Tools::Hgmi::Predict->create(
        organism_name    => $config->{organism_name},
        locus_tag        => $config->{locus_tag},
        project_type     => $config->{project_type},
        ncbi_taxonomy_id => $config->{ncbi_taxonomy_id},
        gram_stain       => $config->{gram_stain},
        locus_id         => $config->{locus_id},

    );

    if ( $self->dev )
    {
        $predict->dev(1);
    }

    # to use new predictscript if changes get made.
    if (exists($config->{predict_script_location}) && (-x $config->{predict_script_location}) )
    {
        $predict->script_location($config->{predict_script_location});
        $self->status_message("using predict script ". $config->{predict_script_location});
    }

    if ($predict)
    {
        $predict->execute()
            or croak
            "can't run bap_predict_genes.pl step.... from Hap.pm\n\n";
    }
    else
    {
        croak "can't set up bap_predict_genes.pl step.... from Hap.pm\n\n";
    }

    my %merge_params = (
        organism_name => $config->{organism_name},
        locus_tag     => $config->{locus_tag},
        project_type  => $config->{project_type},
        runner_count  => $config->{runner_count},
    );

    if (exists($config->{nr_db})) {
        $merge_params{nr_db} = $config->{nr_db};
    }
    
    my $merge = Genome::Model::Tools::Hgmi::Merge->create(%merge_params);

    if (exists($config->{merge_script_location}) && (-x $config->{merge_script_location}) )
    {
        $merge->script_location($config->{merge_script_location});
        $self->status_message("using merge script ". $config->{merge_script_location});
    }


    if ( $self->dev )
    {
        $merge->dev(1);
    }

    if ($merge)
    {
        $merge->execute()
            or croak "can't run bap_merge_genes.pl step... from Hap.pm\n\n";
    }
    else
    {
        croak "can't set up bap_merge_genes.pl step... from Hap.pm\n\n";
    }

    # this needs to get the sequence set name and sequence set id somehow.
    my $ssid = $merge->sequence_set_id();

    # tag 100% overlaps

    my $ovtag = Genome::Model::Tools::Bacterial::TagOverlaps->create( sequence_set_id => $ssid );

    if(defined($self->dev)) {
        $ovtag->dev(1);
    }
    if($ovtag)
    {
        $ovtag->execute()
            or croak "can't tag 100% overlaps in Hap.pm";
    }
    else
    {
        croak "can't create 100% tag overlapping in Hap.pm";
    }

    my %finish_params = (
        sequence_set_id  => $ssid,
        locus_tag        => $config->{locus_tag},
        organism_name    => $config->{organism_name},
        project_type     => $config->{project_type},
        acedb_version    => $config->{acedb_version},
        assembly_name    => $config->{assembly_name},
        org_dirname      => $config->{org_dirname},
        assembly_version => $config->{assembly_version},
        pipe_version     => $config->{pipe_version},
        path             => $config->{path},
    );

    if (exists($config->{nr_db})) {
        $finish_params{nr_db} = $config->{nr_db};
    }
    
    my $fin = Genome::Model::Tools::Hgmi::Finish->create(%finish_params);

    if ( $self->dev )
    {
        $fin->dev(1);
    }

    if ( exists( $config->{skip_acedb_parse} ) )
    {

        $fin->skip_acedb_parse(1);

    }

    if( exists( $config->{finish_script_location}) && -f $config->{finish_script_location} )
    {
        $self->status_message("changing finish script location to ". $config->{finish_script_location});
        $fin->script_location($config->{finish_script_location});
    }

    if ($fin)
    {
        $fin->execute() or croak "can't run finish step... Hap.pm\n\n";
    }
    else
    {
        croak "can't set up finish step... Hap.pm\n\n";
    }


    # core genes and rrna screens
    $next_dir = $config->{path} . "/"
        . $config->{org_dirname} . "/"
        . $config->{assembly_name} . "/"
        . $config->{assembly_version} . "/"
        . "Genbank_submission/"
        . $config->{pipe_version}
        . "/Annotated_submission";

    chdir($next_dir);

    unless( $self->skip_core_check )
    {
        warn qq{\n\nRunning core genes ... Hap.pm\n\n};
        $self->status_message("\n\nRunning core genes... Hap.pm\n\n");


        # have a skip-core-gene flag here that skips this check.
        my $coregene = Genome::Model::Tools::Hgmi::CoreGenes->create(
            cell_type       => $config->{cell_type},
            sequence_set_id => $ssid,
        );

        if ( $self->dev )
        {
            $coregene->dev(1);
        }

        if ($coregene)
        {
            $coregene->execute() or croak "can't execute core gene screen";
        }
        else
        {
            croak "can't set up core gene step... Hap.pm\n\n";
        }
    }
    else
    {
        $self->status_message("Skipping core genes... Hap.pm\n\n");
    }


    warn qq{\n\nRunning rRNA screening step ... Hap.pm\n\n};
#    $self->status_message("Running rRNA screening");

    # rrna screen step
    my $rrnascreen = Genome::Model::Tools::Hgmi::RrnaScreen->create(
        sequence_set_id => $ssid, );

    if ( $self->dev )
    {
        $rrnascreen->dev(1);
    }

    if ($rrnascreen)
    {
        $rrnascreen->execute() or croak "can't execute rrna screen";
    }
    else
    {
        croak "can't set up rrna screen step... Hap.pm\n\n";
    }

    # need to copy over the delete.rrna.ace file, and possibly load the file into
    # acedb
    # file seems to land in $config->{path}/$config->{orgname_dir}/$config->{assembly_name}/$config->{assembly_version}/Genbank_submission/Version_1.0/Annotated_submission/
    my $delete_rrna = $config->{path}."/".$config->{orgname_dir}."/".$config->{assembly_name}."/".$config->{assembly_version}."/Genbank_submission/Version_1.0/Annotated_submission/delete.rrnahits.ace";
    if( -e $delete_rrna )
    {
        my $delete_rrna_dest = $config->{path}."/Acedb/".$config->{acedb_version}."/ace_files/".$self->locus_tag;
        #my $acedbpath = $config->{path} . "/Acedb/". $acedb_version ;
        system("cp $delete_rrna $delete_rrna_dest");
    }

    if($self->skip_protein_annotation)
    {
        $self->status_message("run complete, skipping protein annotation");
        my ($dump_out,$dump_err); 
        #need to specify output path, and filename(s)
        #my $outputdir = $config->{path} . "/" . $config->{org_dirname} . "/"
        #. $config->{assembly_name} . "/"
        #. $config->{assembly_version} . "/" . "Sequence/Unmasked/";
        #my $acedb_version = acedb_version_lookup($config->{acedb_version});
        #my $acedbpath = $config->{path} . "/Acedb/". $acedb_version ;
        ## change this to spit out sequence from oracle.
        #IPC::Run::run(['ace2seq-dump', $acedbpath, $config->{locus_tag}, '-n', '--output', $outputdir,
        #                '--seqfile', $config->{assembly_name}.".cds.fa" ],
        #              '>',
        #              \$dump_out,
        #              '2>',
        #              \$dump_err,) or croak "can't dump sequence from acedb: $CHILD_ERROR";
        ##dna dump here????
        return 1;
    }

    warn qq{\n\nBeginning to run SendToPap.pm(workflow) ... from Hap.pm\n\n};
#    $self->status_message("starting send-to-pap/PAP workflow...");

    unless ( defined( $config->{workflowxml} ) )
    {
        return 1;
    }

    {
        my $gram_stain = $config->{gram_stain};

        unless ( defined($gram_stain) )
        {
            die
                'cannot start workflow - no gram_stain specified in config file...Hap.pm\n\n';
        }

        unless ( ( $gram_stain eq 'positive' )
            || ( $gram_stain eq 'negative' ) )
        {
            die
                "cannot start workflow - gram_stain must be 'postive' or 'negative', not '$gram_stain'...Hap.pm\n\n";
        }

    }

    my $base_archive_dir = File::Spec->catdir(
        $config->{path},          $config->{org_dirname},
        $config->{assembly_name}, $config->{assembly_version},
    );

    my $blastp_archive_dir = File::Spec->catdir( $base_archive_dir, 'Blastp',
        $config->{pipe_version}, 'Hybrid', );

    my $interpro_archive_dir
        = File::Spec->catdir( $base_archive_dir, 'Interpro',
        $config->{pipe_version}, 'Hybrid', );

    my $keggscan_archive_dir = File::Spec->catfile(
        $base_archive_dir, 'Kegg', $config->{pipe_version},
        'Hybrid',
        join( '.', 'KS-OUTPUT', $config->{locus_tag}, 'CDS', 'pep', ),
    );

    foreach my $archive_dir ( $blastp_archive_dir, $interpro_archive_dir,
        $keggscan_archive_dir )
    {
        mkpath($archive_dir);
    }

    my $send = Genome::Model::Tools::Hgmi::SendToPap->create(
        'locus_tag'            => $config->{locus_tag},
        'sequence_set_id'      => $ssid,
        'sequence_name'        => $config->{assembly_name},
        'organism_name'        => $config->{organism_name},
        'workflow_xml'         => $config->{workflowxml},
        'gram_stain'           => $config->{gram_stain},
        'blastp_archive_dir'   => $blastp_archive_dir,
        'interpro_archive_dir' => $interpro_archive_dir,
        'keggscan_archive_dir' => $keggscan_archive_dir,

        # pepfile should be constructed automagically here.
    );

    if ( $self->dev )
    {
        $send->dev(1);
    }

    if ($send)
    {
        $send->execute() or croak "can't run workflow pap step in Hap.pm\n\n";
    }
    else
    {
        croak "can't set up workflow pap step... Hap.pm\n\n";
    }

    # jcvi product naming goes here.
    # need tochdir
    # $path/Acedb/$acedb_version/ace_files/$locus_tag/$pipe_version
    unless($self->skip_ber) 
    {

        my $acedb_version
            = $self->acedb_version_lookup( $config->{acedb_version} );

        $next_dir = $config->{path}
            . "/Acedb/"
            . $acedb_version
            . "/ace_files/"
            . $config->{locus_tag} . "/"
            . $config->{pipe_version};

        warn qq{\n\nACEDB_Dir: $acedb_version\n\n};

        unless ( -d $next_dir )
        {
            croak
                qq{\n\nThe directory : '$next_dir', does not exit, from Hap.pm: $OS_ERROR\n\n};
        }
        my $cwd = getcwd();
        unless ( $cwd eq $next_dir )
        {
            chdir($next_dir)
                or croak
                "Failed to change to '$next_dir', from Hap.pm: $OS_ERROR\n\n";
        }

        #run /gsc/scripts/gsc/annotation/biosql2ace <locus_tag>
        # make sure files are not blank. croak if they are

        my @biosql2ace = (
            'biosql2ace',
            $config->{locus_tag},
        );
        if ( $self->dev )
        {
            push( @biosql2ace, '--dev' );
        }
        my ( $b2a_out, $b2a_err );
        IPC::Run::run( \@biosql2ace, '>', \$b2a_out, '2>', \$b2a_err )
            or croak "cant dump biosql to ace\n\n";

    # check that output files are not empty
        my @outputfiles = ( );
        if($config->{workflowxml} =~ /noblastp/)
        {
            @outputfiles = qw(merged.raw.sorted.ace merged.raw.sorted.ipr.ace REPORT-top_new.ks.ace)
        }
        else
        {
            @outputfiles = qw(briefID.fof.ace merged.raw.sorted.ace merged.raw.sorted.ipr.ace REPORT-top_new.ks.ace)
        }

        foreach my $outputfile ( @outputfiles )
        {
            my $size = -s $outputfile;
            if ( $size == 0 )
            {
                croak
                    "file from biosql2ace dump, $outputfile , is empty...from Hap.pm\n\n";
            }
        }

        my $ber_config = undef;

        my $jcvi = Genome::Model::Tools::Ber::AmgapBerProtName->create(
            sequence_set_id => $ssid,
            config          => $self->config(),
        );

        if ( $self->dev )
        {
            $jcvi->dev(1);
        }

        if ($jcvi)
        {
            $jcvi->execute()
                or croak
                "can't run protein product naming step...from Hap.pm\n\n";
        }
        else
        {
            croak "can't set up product naming step...from Hap.pm\n\n";
        }
    } # ber skipping

    return 1;
}

sub read_config
{
    my $self = shift;

    my $conf = $self->config;
    unless ( -f $conf )
    {
        carp "no config file $conf ...Hap.pm\n\n";
        return undef;
    }

    my $confhash = LoadFile($conf);

    return 1;
}

sub build_empty_config
{
    my $self     = shift;
    my $dumpfile = $self->config;
    my $config   = {

        #dir builder stuff
        'path'          => "",
        'org_dirname'   => "<organism abbreviated name>",
        'assembly_name' =>
            "<full org name, locus_tag, finish assembly, pipeline>",
        'assembly_version' => "",
        'pipe_version'     => "",
        'cell_type'        => "<BACTERIA or ARCHEA or VIRAL>",

        #collect sequence stuff
        'seq_file_name'  => "",
        'seq_file_dir'   => "",
        'minimum_length' => "",

        # sequence name
        'assembly_version' => "",
        'locus_id'         => "<locus_tag w/o DFT/FNL>",
        'acedb_version'    => "",

        #mk prediction mods
        'locus_tag' => "",

        #predict
        'runner_count'            => "",
        'organism_name'           => "",
        'project_type'            => "",
        'gram_stain'              => "",
        'ncbi_taxonomy_id'        => "",
        'predict_script_location' => "<optional>",

        #merge
        # uses some of the same items from predict
        'merge_script_location' => "<optional>",

        #finish
        # uses some of the same items from predict
        'acedb_version'          => "",
        'skip_acedb_parse'       => "<optional>",
        'finish_script_location' => "<optional>",
        'workflowxml'            => "",
    };
    DumpFile( $dumpfile, $config );    # check return?
    return 1;
}

sub acedb_version_lookup
{
    my $self         = shift;
    my $v            = shift;
    my $acedb_lookup = undef;

    my %acedb_version_lookup = (
        'V1'  => 'Version_1.0',
        'V2'  => 'Version_2.0',
        'V3'  => 'Version_3.0',
        'V4'  => 'Version_4.0',
        'V5'  => 'Version_5.0',
        'V6'  => 'Version_6.0',
        'V7'  => 'Version_7.0',
        'V8'  => 'Version_8.0',
        'V9'  => 'Version_9.0',
        'V10' => 'Version_10.0',
    );

    if ( exists( $acedb_version_lookup{$v} ) )
    {
        $acedb_lookup = $acedb_version_lookup{$v};
    }

    return $acedb_lookup;
}



1;

# $Id$
