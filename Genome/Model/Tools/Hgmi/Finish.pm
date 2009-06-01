package Genome::Model::Tools::Hgmi::Finish;


use strict;
use warnings;

use Genome;
use Command;
use Carp;
use DateTime;
use List::MoreUtils qw/ uniq /;
use IPC::Run qw/ run /;

use BAP::DB::Organism;
use BAP::DB::SequenceSet;
use BAP::DB::Sequence;

use Bio::SeqIO;
use Cwd;
use English;

UR::Object::Type->define(
                         class_name => __PACKAGE__,
                         is => 'Command',
                         has => [
                                 'organism_name' => {is => 'String',
                                                     doc => "" },
                                 'locus_tag' => {is => 'String',
                                                      doc => "" },
                                 'project_type' => {is => 'String',
                                                    doc => "" },
                                 'nr_db'        => {is => 'String',
                                                    doc => "path to nr seq db",
                                                    is_optional => 1,
                                                    default => "/gscmnt/temp110/analysis/blast_db/gsc_bacterial/bacterial_nr/bacterial_nr"},
                                 'locus' => {is => 'String',
                                        doc => "",
                                        is_optional => 1},
                                 'gram_stain' => {is => 'String',
                                                  doc => "",
                                                  is_optional => 1},
                                 'ncbi_taxonomy_id' => {is => 'String',
                                                        doc => "",
                                                        is_optional => 1},
                                 'dev' => {is => 'Boolean',
                                           doc => "",
                                           is_optional => 1},
                                 'sequence_set_id' => { is => 'Integer',
                                                        doc => "sequence set id" ,
                                                        is_optional => 1},
                                 'acedb_version' => { is => 'String',
                                                      doc => "Ace DB version (V1,V2,etc)" },
                                 'sequence_set_name' => {is => 'String',
                                                         doc => "",
                                                         is_optional => 1},
                                 'work_directory' => {is => 'String',
                                                      doc => "",
                                                      is_optional => 1},
                                 'script_location' => {is => 'String',
                                                       doc => "path or name of bap finish project script",
                                                       is_optional => 1,
                                                       default => "bap_finish_project",},
				 'skip_acedb_parse' => {is => 'Boolean',
							doc => "skip parsing into acedb for testing",
							is_optional => 1, default => 0 }
				 
                                 ]
                         );

sub help_brief
{
    "tool for running the finish step (bap_finish_genes).  Not finished."
}

sub help_synopsis
{
    my $self = shift;
    return <<"EOS"
Runs the finish step (bap_finish_genes).
EOS

}

sub help_detail
{
    my $self = shift;
    return <<"EOS"
Runs the finish step (bap_finish_genes).
EOS

}

sub execute
{
    my $self = shift;

    my @finish_command = $self->gather_details();

    IPC::Run::run( @finish_command ) || croak "can't run finish : $OS_ERROR  Finish.pm\n\n";

    return 1;
}

sub gather_details
{
    my $self = shift;
    my $organism_name = $self->organism_name;
    my $locus_tag = $self->locus_tag;
    my $project_type = $self->project_type;
    my ($ncbi_taxonomy_id, $gram_stain, $locus, $organism_id, );
    if (defined($self->dev)) { $BAP::DB::DBI::db_env = 'dev'; }
    my $organism_obj = BAP::DB::Organism->retrieve('organism_name'=> $organism_name);

    unless (defined($organism_obj)) 
    {
        croak " organism_obj is not set - are you running this before the predict and merge steps? Finish.pm\n\n";
    }

    $organism_name     = $organism_obj->organism_name();
    $organism_id       = $organism_obj->organism_id();
    $ncbi_taxonomy_id  = $organism_obj->ncbi_taxonomy_id();
    $gram_stain        = $organism_obj->gram_stain();
    $locus             = $organism_obj->locus();
    my @cols = ($organism_id, $organism_name, 
                $ncbi_taxonomy_id, $gram_stain, $locus);
    @cols = map { defined($_) ? $_ : 'NULL' } @cols;
    
    print join("\t", @cols), "\n\n";
    my $cwd;
    if(defined($self->work_directory))
    {
        $cwd = $self->work_directory;
    }
    else
    {
        $cwd = getcwd();
    }
    my @cwd = split(/\//x,$cwd);
    #print "there are ", $#cwd," in \@cwd\n";
    my ($sequence_set_name, $analysis_version_num, $hgmi_sequence_dir);

    # these below are dangerous - perhaps set these differently?
    if ($project_type =~ /HGMI/x )
    {
        # these need to be based on the directory structure,
        # instead of just a 'raw' split.
        $sequence_set_name = $cwd[6]; #HGMI projects
#        $analysis_version_num = $cwd[9]; #HGMI projects
#        $hgmi_sequence_dir = join("\/", @cwd[0..9],'Sequence',$hgmi_locus_tag); #HGMI projects
        
    }
    else # HMPP/Enterobacter
    {
    
        $sequence_set_name = $cwd[7]; #HMPP and Enterobacter
#        $analysis_version_num = $cwd[10]; #HMPP and Enterobacter
#        $hgmi_sequence_dir = join("\/", @cwd[0..10],'Sequence',$hgmi_locus_tag); #HMPP and Enterobacter
        
    }

#    if(defined($self->sequence_set_name))
#    {
#        $sequence_set_name = $self->sequence_set_name;
#    }

    unless (defined($sequence_set_name)) 
    {
        croak " sequence_set_name is not set! Finish.pm\n\n";
    }

    my $sequence_set_name_obj;
    my $sequence_set_obj;
    my $sequence_set_id = $self->sequence_set_id;

    $sequence_set_name_obj = BAP::DB::SequenceSet->retrieve('sequence_set_name'=> $sequence_set_name);

    unless(defined($sequence_set_name_obj))
    {
        croak "nothing found for $sequence_set_name,\nperhaps you are running this before the predict and merge steps?Finish.pm\n\n ";
    }
    else
    {
        print "Sequence-set-name: '$sequence_set_name' already ready!! Here is your information:\n\n";
    }

    unless (defined($sequence_set_id))
    {
        $sequence_set_id = $sequence_set_name_obj->sequence_set_id();
    }

    my @list =($organism_id,$sequence_set_name, $sequence_set_id);
    print join("\t",@list),"\n\n";

    my $bapfinish_output = $cwd."/".$locus_tag."_bfp_BAP_screenoutput".$sequence_set_id.".txt";

    print "\nbap_finish_project.pl\n";

    my @command_list = ('bap_finish_project',
                        '--sequence-set-id',
                        $sequence_set_id,
                        '--locus-id',
                        $locus_tag,
                        '--project-type',
                        $self->project_type,
                        '--acedb-version',
                        $self->acedb_version,
                        );

    if(defined($self->dev)) { push(@command_list,"--dev"); }
    if(defined($self->skip_acedb_parse)) { push(@command_list, "--no-acedb");}

    print "\n", join(' ', @command_list), "\n";

    my @ipc = (
               \@command_list,
               \undef,
               '2>&1',
               $bapfinish_output,
           );

    return @ipc;
}



1;
