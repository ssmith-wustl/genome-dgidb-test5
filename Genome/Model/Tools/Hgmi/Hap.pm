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
use File::Path qw(mkpath);
use File::Spec;
use YAML qw( LoadFile DumpFile );

# should have a crap load of options.
UR::Object::Type->define(
                         class_name => __PACKAGE__,
                         is => 'Command',
                         has => [
                                 'config'       => { is => 'String',
						     doc => "YAML file for reading"},
                                 'gen_example'  => { is => 'Boolean',
						     doc => "Generate an example yaml config file",
						     is_optional => 1},
                                 'internalhash' => { is => 'HashRef',
                                                     doc => "internal",
                                                     is_optional => 1},
                                 'dev'          => { is => 'Boolean',
						     doc => "development flag for testing",
						     is_optional => 1}

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


    if(defined($self->gen_example))
    {
        if( -f $self->config )
        {
            croak "cowardly refusing to overwrite existing file! Hap.pm \n\n";
        }

        $self->build_empty_config();
        return 1;
    }


    if(-f $self->config)
    {
        $self->internalhash(LoadFile($self->config));
    }
    else
    {
        # blow up...
        my $file = $self->config;
        carp "non-existent file $file Hap.pm\n\n";
        return 0;
    }


    my $config = $self->internalhash;
    # dir-builder
    my $d = Genome::Model::Tools::Hgmi::DirBuilder->create(
                                                           path                  => $config->{path},
                                                           org_dirname           => $config->{org_dirname},
                                                           assembly_version_name => $config->{assembly_name},
                                                           assembly_version      => $config->{assembly_version},
                                                           pipe_version          => $config->{pipe_version},
                                                           cell_type             => $config->{cell_type}
                                                           );
    
    if($d)
    {
        $d->execute() or croak "can't run dir-builder Hap.pm\n\n";
    }
    else
    {
        croak "can't set up dir-builder";
    }

    my $next_dir = $config->{path}."/".$config->{org_dirname}."/".
        $config->{assembly_name} . "/". $config->{assembly_version} . "/".
        "Sequence/Unmasked";
    chdir($next_dir);

    # collect-sequence
    my $cs = Genome::Model::Tools::Hgmi::CollectSequence->create(
								 seq_file_name  => $config->{seq_file_name},
								 seq_file_dir   => $config->{seq_file_dir},
								 minimum_length => $config->{minimum_length}, 
                                                                  );

    if($cs)
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

                                                              );

    if($sn)
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
    $next_dir = $config->{path}."/".$config->{org_dirname}."/".
        $config->{assembly_name} . "/". $config->{assembly_version} . "/".
        "BAP"."/". $config->{pipe_version} . "/Sequence";
    chdir($next_dir);

    my $model = Genome::Model::Tools::Hgmi::MkPredictionModels->create(
                                                                      locus_tag  => $config->{locus_tag},
                                                                      fasta_file => $sn->new_output ,
                                                                      );

    if($model)
    {
        $model->execute() or croak "can't run mk-prediction-model Hap.pm\n\n";
    }
    else
    {
        croak "can't set up mk-prediction-model Hap.pm\n\n";
    }

    $next_dir = $config->{path}."/".$config->{org_dirname}."/".
        $config->{assembly_name} . "/". $config->{assembly_version} . "/".
        "BAP"."/". $config->{pipe_version} ;
    chdir($next_dir);

    my $predict = Genome::Model::Tools::Hgmi::Predict->create(
                                                              organism_name => $config->{organism_name} ,
                                                              locus_tag => $config->{locus_tag} ,
                                                              project_type => $config->{project_type} ,
							      ncbi_taxonomy_id => $config->{ncbi_taxonomy_id},
							      gram_stain => $config->{gram_stain},
							      locus_id => $config->{locus_id},
                                                              
                                                              );

    if($self->dev)
    {
        $predict->dev(1);
    }
    
    if($predict)
    {
        $predict->execute() or croak "can't run bap_predict_genes.pl step.... from Hap.pm\n\n";
    }
    else
    {
        croak "can't set up bap_predict_genes.pl step.... from Hap.pm\n\n";
    }

    my $merge = Genome::Model::Tools::Hgmi::Merge->create(
							  organism_name => $config->{organism_name},
                                                          locus_tag     => $config->{locus_tag},
							  project_type  => $config->{project_type},
							  runner_count  => $config->{runner_count},
                                                          );

    if($self->dev)
    {
        $merge->dev(1);
    }

    if($merge)
    {
        $merge->execute() or croak "can't run bap_merge_genes.pl step... from Hap.pm\n\n";
    }
    else
    {
        croak "can't set up bap_merge_genes.pl step... from Hap.pm\n\n";
    }

    # this needs to get the sequence set name and sequence set id somehow.
    my $ssid = $merge->sequence_set_id();

    my $fin = Genome::Model::Tools::Hgmi::Finish->create(
	                                                 sequence_set_id  => $ssid ,
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

    if($self->dev)
    {
        $fin->dev(1);
    }

    if(exists($config->{skip_acedb_parse})) {
	
	$fin->skip_acedb_parse(1);

    }

    if($fin)
    {
        $fin->execute() or croak "can't run finish step... Hap.pm\n\n";
    }
    else
    {
        croak "can't set up finish step... Hap.pm\n\n";
    }

    warn qq{\n\nRunning core genes ... Hap.pm\n\n};

    # core genes and rrna screens
    $next_dir = $config->{path}."/".$config->{org_dirname}."/".
        $config->{assembly_name} . "/". $config->{assembly_version} . "/".
        "Genbank_submission/Version_1.0/Annotated_submisstion";
    chdir($next_dir);

    my $coregene = Genome::Model::Tools::Hgmi::CoreGenes->create(
        cell_type => $config->{cell_type},
        sequence_set_id => $ssid,
    );
  
    if($self->dev)
    {
        $coregene->dev(1);
    }

    if($coregene)
    {
        $coregene->execute() or croak "can't execute core gene screen";
    }
    else
    {
        croak "can't set up core gene step... Hap.pm\n\n";
    }

    warn qq{\n\nRunning rRNA screening step ... Hap.pm\n\n};

    # rrna screen step
    my $rrnascreen = Genome::Model::Tools::Hgmi::RrnaScreen->create(
        sequence_set_id => $ssid,
    );
  
    if($self->dev)
    {
        $rrnascreen->dev(1);
    }

    if($coregene)
    {
        $rrnascreen->execute() or croak "can't execute core gene screen";
    }
    else
    {
        croak "can't set up rrna screen step... Hap.pm\n\n";
    }

    warn qq{\n\nBeginning to run SendToPap.pm(workflow) ... from Hap.pm\n\n};

    unless(defined($config->{workflowxml}))
    {
        return 1;
    }

    {
        my $gram_stain = $config->{gram_stain};
    
        unless (defined($gram_stain)) {
            die 'cannot start workflow - no gram_stain specified in config file...Hap.pm\n\n';
        }
       
        unless (($gram_stain eq 'positive') || ($gram_stain eq 'negative')) {
            die "cannot start workflow - gram_stain must be 'postive' or 'negative', not '$gram_stain'...Hap.pm\n\n";
        }
       
    }


    my $base_archive_dir = File::Spec->catdir(
                                              $config->{path},
                                              $config->{org_dirname},
                                              $config->{assembly_name},
                                              $config->{assembly_version},
                                          );
    
    my $blastp_archive_dir   = File::Spec->catdir(
                                                  $base_archive_dir,
                                                  'Blastp',
                                                  $config->{pipe_version},
                                                  'Hybrid',
                                              );
    
    my $interpro_archive_dir = File::Spec->catdir(
                                                  $base_archive_dir,
                                                  'Interpro',
                                                  $config->{pipe_version},
                                                  'Hybrid',
                                              );

    my $keggscan_archive_dir = File::Spec->catfile(
                                                   $base_archive_dir,
                                                   'Kegg',
                                                   $config->{pipe_version},
                                                   'Hybrid',
                                                   join(
                                                        '.',
                                                        'KS-OUTPUT',
                                                        $config->{locus_tag},
                                                        'CDS',
                                                        'pep',
                                                        ),
                                               );
   
    foreach my $archive_dir ($blastp_archive_dir, $interpro_archive_dir, $keggscan_archive_dir) {
        mkpath($archive_dir);
    }
    
    my $send = Genome::Model::Tools::Hgmi::SendToPap->create(
                                                             'locus_tag'            => $config->{locus_tag},
                                                             'sequence_set_id'      => $ssid, 
                                                             'workflow_xml'         => $config->{workflowxml},
                                                             'gram_stain'           => $config->{gram_stain},
                                                             'blastp_archive_dir'   => $blastp_archive_dir,
                                                             'interpro_archive_dir' => $interpro_archive_dir,
                                                             'keggscan_archive_dir' => $keggscan_archive_dir,
                                                             # pepfile should be constructed automagically here.
                                                         );

    if($self->dev)
    {
        $send->dev(1);
    }
    
    if($send)
    {
        $send->execute() or croak "can't run workflow pap step in Hap.pm\n\n";
    }
    else
    {
        croak "can't set up workflow pap step... Hap.pm\n\n";
    }

    return 1;
}


sub read_config
{
    my $self = shift;
    
    my $conf = $self->config;
    unless(-f $conf)
    {
        carp "no config file $conf ...Hap.pm\n\n";
        return undef;
    }

    my $confhash = LoadFile($conf);

    return 1;
}


sub build_empty_config
{
    my $self = shift;
    my $dumpfile =  $self->config;
    my $config = {
                  #dir builder stuff
                  'path' => "",
                  'org_dirname' => "<organism abbreviated name>",
                  'assembly_name' => "<full org name, locus_tag, finish assembly, pipeline>",
                  'assembly_version' => "",
                  'pipe_version' => "",
                  'cell_type' => "",
                  #collect sequence stuff
                  'seq_file_name' => "",
		  'seq_file_dir'=> "",
                  'minimum_length' => "",
		  # sequence name
		  'assembly_version' => "",
                  'locus_id' => "<locus_tag w/o DFT/FNL>",
                  'acedb_version' => "",
                  #mk prediction mods
                  'locus_tag' => "",
		  #predict
		  'runner_count' => "",
                  'organism_name' => "",
		  'project_type' => "",
		  'gram_stain' => "",
                  'ncbi_taxonomy_id' => "",
		  'predict_script_location' => "<optional>",
                  #merge
                  # uses some of the same items from predict
                  'merge_script_location' => "<optional>",
		  #finish
                  # uses some of the same items from predict
                  'acedb_version' => "",
		  'skip_acedb_parse' => "<optional>",
                  'finish_script_location' => "<optional>",
                  'workflowxml' => "",
                  };
    DumpFile($dumpfile, $config); # check return?
    return 1;
}



1;

# $Id$
