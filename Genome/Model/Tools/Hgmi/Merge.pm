package Genome::Model::Tools::Hgmi::Merge;


use strict;
use warnings;

use Genome;
use Command;
use Carp;
use DateTime;
use List::MoreUtils qw/ uniq /;
use IPC::Run qw/ run /;
use Cwd;
require "pwd.pl";
use English;

use BAP::DB::Organism;
use BAP::DB::SequenceSet;
use BAP::DB::Sequence;
use Data::Dumper;

use Bio::SeqIO;


UR::Object::Type->define(
                         class_name => __PACKAGE__,
                         is => 'Command',
                         has => [
                                 'organism_name'    => {is => 'String',
							doc => "Organism's latin name" ,
						       },
                                 'locus_tag'        => {is => 'String',
							doc => "Locus tag for project, containing DFT/FNL postpended",
						       },
                                 'project_type'     => {is => 'String',
							doc => "Type of project" ,
						       },
                                 'nr_db'            => {is => 'String',
							doc => "path to nr seq db",
							is_optional => 1,
							default => "/gscmnt/temp110/analysis/blast_db/gsc_bacterial/bacterial_nr/bacterial_nr",
						       },
                                 'locus_id'         => {is => 'String',
							doc => "locus_tag with OUT DFT/FNL postpended",
							is_optional => 1,
						       },
                                 'gram_stain'       => {is => 'String',
							doc => "gram stain for bacteria (positive or negative)",
							is_optional => 1,
						       },
                                 'ncbi_taxonomy_id' => {is => 'String',
                                                        doc => "NCBI taxonomy id",
                                                        is_optional =>1,
						       },
                                 'dev'              => {is => 'Boolean',
							doc => "use development db",
							is_optional => 1,
						       },
                                 'work_directory'   => {is => 'String',
							doc => "work directory",
							is_optional => 1,
						       },
                                 'sequence_set_id'  => { is => 'Integer',
							 doc => "sequence set id",
							 is_optional => 1,
						       },
				 'runner_count'     => { is => 'Integer',
							 doc => "runner_count",
							 default => 10,
							 is_optional => 1,
						       },
                 'script_location'  => { is => 'String',
                                         doc => "default location for merge genes script",
                                         is_optional => 1,
                                         default => '/gsc/scripts/gsc/annotation/bap_merge_genes',
                                        },
                                 ]
                         );

sub help_brief
{
    "tool for running the merge step (bap_merge_genes)."
}

sub help_synopsis
{
    my $self = shift;
    return <<"EOS"
Runs the merge step (bap_merge_genes).
EOS

}

sub help_detail
{
    my $self = shift;
    return <<"EOS"
Runs the merge step (bap_merge_genes).
EOS

}


sub execute
{
    my $self = shift;

    my @merge = $self->gather_details();

    my ($merge_out, $merge_err); 
    IPC::Run::run(\@merge,
                  \undef,
                  '>',
                  \$merge_out,
                  '2>',
                  \$merge_err) || croak "can't run Merge.pm : $CHILD_ERROR : ".$merge[$#merge]."\n$merge_out\n===\n$merge_err\n";

    return 1;
    
}


sub gather_details
{
    my $self = shift;

    my $organism_name  = $self->organism_name;
    my $locus_tag      = $self->locus_tag;
    my $project_type   = $self->project_type;
    my $runner_count   = $self->runner_count;
    my $nr_db          = $self->nr_db;

    my ($ncbi_taxonomy_id, $gram_stain, $locus, $organism_id, );

    if (defined($self->dev)) { $BAP::DB::DBI::db_env = 'dev'; }
    my $organism_obj = BAP::DB::Organism->retrieve('organism_name'=> $organism_name);

    if (defined($organism_obj)) { 
        print "\n$organism_name, already exist!  Here is your information from Merge.pm:\n\n";
    }
    else
    {
        croak "$organism_name not in db, maybe you need to run bap_predict_genes.pl, first? Merge.pm\n";
    }

    $organism_name     = $organism_obj->organism_name();
    $organism_id       = $organism_obj->organism_id();
    $ncbi_taxonomy_id  = $organism_obj->ncbi_taxonomy_id();
    $gram_stain        = $organism_obj->gram_stain();
    $locus             = $organism_obj->locus();

    my @cols = ($organism_id, $organism_name, $ncbi_taxonomy_id, $gram_stain, $locus);
    @cols = map { defined($_) ? $_ : 'NULL' } @cols;

    print join("\t", @cols), "\n\n";

    my $cwd = $self->cwd();
    my @cwd = split(/\//x,$cwd);

    my ($sequence_set_name, $analysis_version_num, $hgmi_sequence_dir);

    # these below are dangerous, should be altered.
    if ($project_type =~ /HGMI/x )
    {
        # these need to be based on the directory structure,
        # instead of just a 'raw' split.
        #unless($#cwd == 9)
        #{
        #    croak "directory structure is wrong in HGMI!?!? Merge.pm";
        #}
        #$sequence_set_name    = $cwd[6]; #HGMI projects
        $sequence_set_name    = $cwd[-4]; #HGMI projects
        #$analysis_version_num = $cwd[9]; #HGMI projects
        $analysis_version_num = $cwd[-1]; #HGMI projects
        $hgmi_sequence_dir    = join("\/", @cwd,'Sequence',$locus_tag); #HGMI projects
        
    }
    else # HMPP/Enterobacter
    {
        unless($#cwd == 10)
        {
            croak "directory structure is wrong in HMPP !?!?!? Merge.pm";
        }
        $sequence_set_name = $cwd[7]; #HMPP and Enterobacter
        $analysis_version_num = $cwd[10]; #HMPP and Enterobacter
        $hgmi_sequence_dir = join("\/", @cwd[0..10],'Sequence',$locus_tag); #HMPP and Enterobacter
        
    }

    unless (defined($sequence_set_name)) 
    {
        croak " sequence_set_name is not set in Merge.pm! ";
    }

    my $sequence_set_name_obj;
    my $sequence_set_obj;
    my $sequence_set_id;

    $sequence_set_name_obj = BAP::DB::SequenceSet->retrieve('sequence_set_name'=> $sequence_set_name);

    if (defined($sequence_set_name_obj)) 
    {
        print "Sequence-set-name: '$sequence_set_name' already exist!! Here is your information from Merge.pm:\n\n";

    }
    else
    {
        croak "sequence set name not setup, maybe you need to run the bap_predict_genes.pl step? Merge.pm\n";
    }

    unless (defined($sequence_set_id))
    {
        $sequence_set_id = $sequence_set_name_obj->sequence_set_id();
    }

    $self->sequence_set_id($sequence_set_id);

    my @list =($organism_id,$sequence_set_name, $sequence_set_id);

    print join("\t",@list),"\n\n";
   
    if (!defined($nr_db)) 
    {
        croak "nr-db: \$nr_db is empty! Merge.pm";
    }
    elsif ( ! -f $nr_db )
    {
        croak "nr-db: ". $nr_db . " doesn't exist! Merge.pm";
    }
    
    my $bmg_job_stdout       = $cwd."/".$locus_tag."_bmg_BAP_job_".$sequence_set_id.".txt";
    my $bmg_job_stderr       = $cwd."/".$locus_tag."_bmg_BAP_job_err_".$sequence_set_id.".txt";
    my $debug_file           = $cwd."/".$locus_tag."_bmg_debug_file_".$sequence_set_id.".txt";
    my $bapmergegenes_output = $cwd."/".$locus_tag."_bmg_BAP_screenoutput_".$sequence_set_id.".txt";
    
    print "\nbap_merge_genes.pl\n";
    
    my $script_location = $self->script_location;
    my @command = (
                   $script_location,
                   '--sequence-set-id',
                   $sequence_set_id,
                   '--job-stdout',
                   $bmg_job_stdout,
                   '--job-stderr',
                   $bmg_job_stderr,
                   '--runner-count',
                   $runner_count,
                   '--debug-file',
                   $debug_file,
                   '--nr-db',
                   $self->nr_db,
               );

    if(defined($self->dev)) { push(@command,"--dev"); }
    
    print "\n", join(' ', @command), "\n";
    
    my @ipc = (
               \@command,
               \undef,
               '2>&1',
               $bapmergegenes_output,
           );
    
    return @ipc;
    
}

sub _cwd {

    my ($self) = @_;

    my $cwd;
    
    if (defined($self->work_directory)) {
        $cwd = $self->work_directory;
    }
    else {
        $cwd = getcwd();
    }

    return $cwd;
    
}

1;

# $Id$
