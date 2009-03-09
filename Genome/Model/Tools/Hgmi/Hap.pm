package Genome::Model::Tools::Hgmi::Hap;

use strict;
use warnings;

use Genome;
use Command;
use Carp;
use Genome::Model::Tools::Hgmi::DirBuilder;
use Genome::Model::Tools::Hgmi::CollectSequence;
use Genome::Model::Tools::Hgmi::SequenceName;
use Genome::Model::Tools::Hgmi::MkPredictionModels;
use Genome::Model::Tools::Hgmi::Predict;
use Genome::Model::Tools::Hgmi::Merge;
use Genome::Model::Tools::Hgmi::Finish;
use Genome::Model::Tools::Hgmi::SendToPap;
use YAML qw( LoadFile DumpFile );

# should have a crap load of options.
UR::Object::Type->define(
                         class_name => __PACKAGE__,
                         is => 'Command',
                         has => [
                                 'config' => { is => 'String',
                                               doc => "YAML file for reading"},
                                 'gen_example' => { is => 'Boolean',
                                                    doc => "Generate an example yaml config file",
                                                    is_optional => 1},
                                 'internalhash' => { is => 'HashRef',
                                                     doc => "internal",
                                                     is_optional => 1},
                                 'dev' => { is => 'Boolean',
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
            croak "cowardly refusing to overwrite existing file!";
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
        carp "non-existent file $file";
        return 0;
    }


    my $config = $self->internalhash;
    # dir-builder
    my $d = Genome::Model::Tools::Hgmi::DirBuilder->create(
                                                           path => $config->{path},
                                                           org_dirname => $config->{org_dirname},
                                                           assembly_version_name => $config->{assembly_name},
                                                           assembly_version => $config->{assembly_version},
                                                           pipe_version => $config->{pipe_version},
                                                           cell_type => $config->{cell_type}
                                                           );
    
    if($d)
    {
        $d->execute() or croak "can't run dir-builder";
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
                                                                  sequence_file => $config->{sequence_file},
                                                                  output => $config->{output},
                                                                  minimum_length => $config->{minimum_length}, 
                                                                  );

    if($cs)
    {
        $cs->execute() or croak "can't run collect-sequence";
    }
    else
    {
        croak "can't set up collect-sequence";
    }

    # sequence-name
    my $sn = Genome::Model::Tools::Hgmi::SequenceName->create(
                                                              locus_id => $config->{locus_id},
                                                              fasta => $config->{output},
                                                              analysis_version => $config->{analysis_version},
                                                              acedb_version => $config->{acedb_version},

                                                              );

    if($sn)
    {
        $sn->execute() or croak "can't run sequence-name";
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
                                                                      locus_tag_prefix => $config->{locus_tag_prefix},
                                                                      fasta_file => $sn->new_output ,
                                                                      );

    if($model)
    {
        $model->execute() or croak "can't run mk-prediction-model";
    }
    else
    {
        croak "can't set up mk-prediction-model";
    }

    $next_dir = $config->{path}."/".$config->{org_dirname}."/".
        $config->{assembly_name} . "/". $config->{assembly_version} . "/".
        "BAP"."/". $config->{pipe_version} ;
    chdir($next_dir);

    my $predict = Genome::Model::Tools::Hgmi::Predict->create(
                                                              organism_name => $config->{org_dirname} ,
                                                              hgmi_locus_tag => $config->{locus_tag_prefix} ,
                                                              project_type => $config->{project_type} ,
                                                              
                                                              );

    if($self->dev)
    {
        $predict->dev(1);
    }
    
    if($predict)
    {
        $predict->execute() or croak "can't run predict step";
    }
    else
    {
        croak "can't set up predict step";
    }

    my $merge = Genome::Model::Tools::Hgmi::Merge->create(
                                                          hgmi_locus_tag => $config->{locus_tag_prefix},
                                                          organism_name => $config->{org_dirname},
                                                          project_type => $config->{project_type},
                                                          );

    if($self->dev)
    {
        $merge->dev(1);
    }

    if($merge)
    {
        $merge->execute() or croak "can't run merge step";
    }
    else
    {
        croak "can't set up merge step";
    }

    # this needs to get the sequence set name and sequence set id somehow.
    my $ssid = $merge->sequence_set_id();

    my $fin = Genome::Model::Tools::Hgmi::Finish->create(
                                                         #sequence_set_name => ,
                                                         sequence_set_id => $ssid ,
                                                         hgmi_locus_tag => $config->{locus_tag_prefix},
                                                         organism_name => $config->{org_dirname},
                                                         project_type => $config->{project_type},
                                                         acedb_version => $config->{acedb_version},
							 skip_acedb_parse => $config->{skip_acedb_parse},
                                                        );

    if($self->dev)
    {
        $fin->dev(1);
    }

    if($fin)
    {
        $fin->execute() or croak "can't run finish step";
    }
    else
    {
        croak "can't set up finish step";
    }

    unless(defined($config->{workflowxml}))
    {
        return 1;
    }

    unless (defined($config->{gram_stain})) {
        die 'cannot start workflow - no gram_stain specified in config file';
    }
    
    my $send = Genome::Model::Tools::Hgmi::SendToPap->create(
                     'locus_tag' => $config->{locus_tag_prefix},
                     'sequence_set_id' => $ssid, 
                     'workflow_xml' => $config->{workflowxml},
                     'gram_stain' => $config->{gram_stain},
# pepfile should be constructed automagically here.
                  );

    if($self->dev)
    {
        $send->dev(1);
    }
    
    if($send)
    {
        $send->execute() or croak "can't run workflow pap step";
    }
    else
    {
        croak "can't set up workflow pap step";
    }

    return 1;
}


sub read_config
{
    my $self = shift;
    
    my $conf = $self->config;
    unless(-f $conf)
    {
        carp "no config file $conf ...";
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
                  'org_dirname' => "",
                  'assembly_name' => "",
                  'assembly_version' => "",
                  'pipe_version' => "",
                  'cell_type' => "",
                  #collect sequence stuff
                  'sequence_file' => "",
                  'minimum_length' => "",
                  'output' => "",
                  # sequence name
                  'fasta' => "",
                  'assembly_version' => "",
                  'locus_id' => "", # same as hgmi_locus_tag?
                  'acedb_version' => "",
                  #mk prediction mods
                  'locus_tag_prefix' => "", # same as hgmi_locus_tag?
                  'fasta_file' => "",
                  #'work_directory' => "",
                  #'gc' => "",
                  #predict
                  'organism_name' => "",
                  'hgmi_locus_tag' => "",
                  'project_type' => "",
                  'locus' => "", # same as hgmi_locus_tag?
                  'gram_stain' => "<optional>",
                  'ncbi_taxonomy_id' => "",
                  'work_directory' => "<optional>",
                  'predict_script_location' => "<optional>",
                  #merge
                  # uses some of the same items from predict
                  'merge_script_location' => "<optional>",
                  #finish
                  # uses some of the same items from predict
                  'acedb_version' => "",
                  'sequence_set_name' => "",
                  'sequence_set_id' => "",
                  'finish_script_location' => "<optional>",
                  'workflowxml' => "",
                  };
    DumpFile($dumpfile, $config); # check return?
    return 1;
}



1;

# $Id$
