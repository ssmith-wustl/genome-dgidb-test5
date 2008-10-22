package Genome::Model::Tools::Hgmi::Merge;


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


UR::Object::Type->define(
                         class_name => __PACKAGE__,
                         is => 'Command',
                         has => [
                                 'organism_name' => {is => 'String',
                                                     doc => "" },
                                 'hgmi_locus_tag' => {is => 'String',
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
                                                  doc => "gram stain for bacteria (positive or negative)",
                                                  is_optional => 1},
                                 'ncbi_taxonomy_id' => {is => 'String',
                                                        doc => "",
                                                        is_optional =>1},
                                 'dev' => {is => 'Boolean',
                                           doc => "use development db",
                                           is_optional => 1},
                                 'work_directory' => {is => 'String',
                                                      doc => "work directory",
                                                      is_optional => 1},
                                 ]
                         );

sub help_brief
{
    "tool for running the merge step (bap_merge_genes).  Not finished."
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
# default for nrdb
#$nr_db = "/gscmnt/temp110/analysis/blast_db/gsc_bacterial/bacterial_nr/bacterial_nr";
    my ($merge_out,$merge_err);
    my $merge_command = $self->gather_details();
    IPC::Run::run( $merge_command,
                   \undef,
                   '>',
                   \$merge_out,
                   '2>',
                   \$merge_err,
                   ) || croak "can't run finish : $!";



    return 1;
}


sub gather_details
{
    my $self = shift;
    my $organism_name = $self->organism_name;
    my $hgmi_locus_tag = $self->hgmi_locus_tag;
    my $project_type = $self->project_type;
    my $nr_db = $self->nr_db;
    my ($ncbi_taxonomy_id, $gram_stain, $locus, $organism_id, );
    if (defined($self->dev)) { $BAP::DB::DBI::db_env = 'dev'; }
    my $organism_obj = BAP::DB::Organism->retrieve('organism_name'=> $organism_name);

    if (defined($organism_obj)) { 
        print "\n$organism_name, already exist!  Here is your information:\n\n";
        
    }
    else
    {
        croak "$organism_name not in db, maybe you need to run predict first?";
    }

    $organism_name     = $organism_obj->organism_name();
    $organism_id       = $organism_obj->organism_id();
    $ncbi_taxonomy_id  = $organism_obj->ncbi_taxonomy_id();
    $gram_stain        = $organism_obj->gram_stain();
    $locus             = $organism_obj->locus();
    my @cols = ($organism_id, $organism_name, $ncbi_taxonomy_id, $gram_stain, $locus);
    @cols = map { defined($_) ? $_ : 'NULL' } @cols;
    
    print join("\t", @cols), "\n\n";
    

    unless (defined($organism_obj)) # am I already checking this up there?
    {
        croak " organism_obj is not set at line 70 ! ";
    }
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

    my ($sequence_set_name, $analysis_version_num, $hgmi_sequence_dir);

    # these below are dangerous
    if ($project_type =~ /HGMI/x )
    {
        # these need to be based on the directory structure,
        # instead of just a 'raw' split.
        unless($#cwd == 9)
        {
            croak "directory structure is wrong!?!?";
        }
        $sequence_set_name = $cwd[6]; #HGMI projects
        $analysis_version_num = $cwd[9]; #HGMI projects
        $hgmi_sequence_dir = join("\/", @cwd[0..9],'Sequence',$hgmi_locus_tag); #HGMI projects
        
    }
    else # HMPP/Enterobacter
    {
        unless($#cwd == 10)
        {
            croak "directory structure is wrong !?!?!?";
        }
        $sequence_set_name = $cwd[7]; #HMPP and Enterobacter
        $analysis_version_num = $cwd[10]; #HMPP and Enterobacter
        $hgmi_sequence_dir = join("\/", @cwd[0..10],'Sequence',$hgmi_locus_tag); #HMPP and Enterobacter
        
    }

    unless (defined($sequence_set_name)) 
    {
        croak " sequence_set_name is not set! ";
    }

    my $sequence_set_name_obj;
    my $sequence_set_obj;
    my $sequence_set_id;

    $sequence_set_name_obj = BAP::DB::SequenceSet->retrieve('sequence_set_name'=> $sequence_set_name);

    if (defined($sequence_set_name_obj)) 
    {
        print "Sequence-set-name: '$sequence_set_name' already exist!! Here is your information:\n\n";

    }
    else
    {
        croak "sequence set name not setup, maybe you need to run the predict step?";
    }

    unless (defined($sequence_set_id))
    {
        $sequence_set_id = $sequence_set_name_obj->sequence_set_id();
    }

    my @list =($organism_id,$sequence_set_name, $sequence_set_id);
    print join("\t",@list),"\n\n";

#items need for bap_predict_genes.pl and print out command

    my (
        $glimmer2_model,
        $glimmer3_model, $glimmer3_pwm,
        $genemark_model,
        $job_stdout, $job_stderr,
        $runner_count,
        $bappredictgenes_output
        );

    $job_stdout     = $cwd."/".$hgmi_locus_tag."_bpg_BAP_job_".$sequence_set_id.".txt";

    $job_stderr     = $cwd."/".$hgmi_locus_tag."_bpg_BAP_job_err_".$sequence_set_id.".txt";

    $runner_count   = 50;

    $bappredictgenes_output = $cwd."/".$hgmi_locus_tag."_bpg_BAP_screenoutput_".$sequence_set_id.".txt";

    my $bsub_output = $cwd."/".$hgmi_locus_tag."_bpg_BAP_".$sequence_set_id.".output";

    my $bsub_error = $cwd."/".$hgmi_locus_tag."_bpg_BAP_".$sequence_set_id.".error";


    if (!defined($nr_db)) 
    {
        croak "nr-db: \$nr_db is empty!";
    }
    elsif ( ! -f $nr_db )
    {
        croak "nr-db: ". $nr_db . " doesn't exist!";
    }
    
    my $bmg_job_stdout = $cwd."/".$hgmi_locus_tag."_bmg_BAP_job_".$sequence_set_id.".txt";
    
    my $bmg_job_stderr = $cwd."/".$hgmi_locus_tag."_bmg_BAP_job_err_".$sequence_set_id.".txt";

    my $debug_file     = $cwd."/".$hgmi_locus_tag."_bmg_debug_file_".$sequence_set_id.".txt";

    my $bapmergegenes_output = $cwd."/".$hgmi_locus_tag."_bmg_BAP_screenoutput_".$sequence_set_id.".txt";

    my $bsub_bmg_output = $cwd."/".$hgmi_locus_tag."_bmg_BAP_".$sequence_set_id."_blade.output";

    my $bsub_bmg_error = $cwd."/".$hgmi_locus_tag."_bmg_BAP_".$sequence_set_id."_blade.error";
    
    my $cmd2;
    $cmd2 .= qq{(bsub -o $bsub_bmg_output -e $bsub_bmg_error -q long -n 2 -R 'span[hosts=1] rusage[mem=4096]' -N -u wnash\@wustl.edu \\\n};
#$cmd2 .= qq{(bap_merge_genes --sequence-set-id $sequence_set_id --job-stdout $bmg_job_stdout \\\n};
            $cmd2 .= qq{bap_merge_genes --sequence-set-id $sequence_set_id --job-stdout $bmg_job_stdout \\\n};
            $cmd2 .= qq{--job-stderr $bmg_job_stderr --runner-count $runner_count --debug-file $debug_file \\\n};
#$cmd2 .= qq{--nr-db $nr_db ) > &  $bapmergegenes_output &\\\n};
            $cmd2 .= qq{--nr-db $nr_db ) > &  $bapmergegenes_output \\\n};
    
    print "\nbap_merge_genes.pl\n";
    print "\n$cmd2 \n";


    my @command_list = ('bap_merge_genes',
                        '--sequence-set-id',
                        $sequence_set_id,
                        '--job-stdout',
                        $job_stdout,
                        '--job-stderr',
                        $job_stderr,
                        '--runner-count',
                        $runner_count,
                        '--debug-file',
                        $debug_file,
                        '--nr-db',
                        $self->nr_db
                        );
    if(defined($self->dev)) { push(@command_list,"--dev"); }
    return \@command_list;
}






1;
