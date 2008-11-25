package Genome::Model::Tools::Hgmi::Predict;


use strict;
use warnings;

use Genome;
use Command;
use Carp;
use File::Slurp;
use IO::Dir;
use DateTime;
use List::MoreUtils qw/ uniq /;
use IPC::Run qw/ run /;

use BAP::DB::Organism;
use BAP::DB::SequenceSet;
use BAP::DB::Sequence;

use Bio::SeqIO;

use Cwd;
#require "pwd.pl";
use Data::Dumper;


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
                                 'locus' => {is => 'String',
                                        doc => "",
                                        is_optional => 1},
                                 'gram_stain' => {is => 'String',
                                                  doc => "",
                                                  is_optional => 1},
                                 'ncbi_taxonomy_id' => {is => 'String',
                                                        doc => "",
                                                        is_optional =>1},
                                 'work_directory' => { is => 'String',
                                                       doc => "",
                                                       is_optional => 1},
                                 'dev' => {is => 'Boolean',
                                           doc => "use development db",
                                           is_optional => 1},
                                 'script_location' => {is => 'String',
                                                       doc =>"location for bap_predict_genes",
                                                       is_optional => 1,
                                                       default => 'bap_predict_genes'},

                                 ]
                         );



sub help_brief
{
    "tool for running the predict step (bap_predict_genes). Not done yet.";
}

sub help_synopsis
{
    my $self = shift;
    return <<"EOS"
Runs predict step (bap_predict_genes).
Not done yet.
EOS

}

sub help_detail
{
    my $self = shift;
    return <<"EOS"
Runs predict step (bap_predict_genes).
Gathers run time paramters for execution.

EOS

}

sub execute
{
    my $self = shift;

    my ($predict_out,$predict_err);
    my $predict_command = $self->gather_details();
    IPC::Run::run( $predict_command,
                   \undef,
                   '>',
                   \$predict_out,
                   '2>',
                   \$predict_err,
                   ) || croak "can't run predict : $!";

    return 1;
}


sub gather_details
{
    my $self = shift;
    my $organism_name = $self->organism_name;
    my $hgmi_locus_tag = $self->hgmi_locus_tag;
    my $project_type = $self->project_type;
    my ($ncbi_taxonomy_id, $gram_stain, $locus, $organism_id, );
    if (defined($self->dev)) { $BAP::DB::DBI::db_env = 'dev'; }
    my $organism_obj = BAP::DB::Organism->retrieve('organism_name'=> $organism_name);

    if (defined($organism_obj)) { 
        print "\n$organism_name, already exist!  Here is your information:\n\n";
        
    }
    else
    {   
        $organism_obj = BAP::DB::Organism->insert({
                                                      'organism_name'    => $organism_name,
                                                      'ncbi_taxonomy_id' => $ncbi_taxonomy_id,
                                                      'gram_stain'       => $gram_stain,
                                                      'locus'            => $locus,
                                                  }
                                                  );
        
    }

    $organism_name     = $organism_obj->organism_name();
    $organism_id       = $organism_obj->organism_id();
    $ncbi_taxonomy_id  = $organism_obj->ncbi_taxonomy_id();
    $gram_stain        = $organism_obj->gram_stain();
    $locus             = $organism_obj->locus();
    my @cols = ($organism_id, $organism_name, $ncbi_taxonomy_id, $gram_stain, $locus);
    @cols = map { defined($_) ? $_ : 'NULL' } @cols;
    
    print join("\t", @cols), "\n\n";
    

    BAP::DB::DBI->dbi_commit();

    unless (defined($organism_obj)) 
    {
        croak " organism_obj is not set at line 70 ! ";
    }

    # cwd should look like:
    # /gscmnt/278/analysis/HGMI/B_catenulatum/Bifidobacterium_catenulatum_BIFCATDFT_1.0_newb/Version_1.0/BAP/Version_1.0
    my $cwd;
    my @cwd;
    if(!defined($self->work_directory))
    {
        $cwd = getcwd();

    }
    else
    {
        $cwd = $self->work_directory;
    }
    @cwd = split(/\//x,$cwd);

    my ($sequence_set_name, $analysis_version_num, $hgmi_sequence_dir);

    # these below are dangerous
    if (($project_type =~ /HGMI/x)  )
    {
        # these need to be based on the directory structure,
        # instead of just a 'raw' split.
        unless($#cwd == 9)
        {
            croak "directory structure is wrong or broken\n$cwd\n$#cwd\n";
        }
        $sequence_set_name = $cwd[6]; #HGMI projects
        $analysis_version_num = $cwd[9]; #HGMI projects
        $hgmi_sequence_dir = join("\/", @cwd[0..9],'Sequence',$hgmi_locus_tag); #HGMI projects
        
    }
    else # HMPP/Enterobacter
    {
        unless($#cwd == 10)
        {
            croak "directory structure is wrong or broken";
        }
        $sequence_set_name = $cwd[7];
        $analysis_version_num = $cwd[10];
        $hgmi_sequence_dir = join("\/", @cwd[0..10],'Sequence',$hgmi_locus_tag); 
        
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
        my $short_ver_num;
        $short_ver_num = $analysis_version_num;
        $short_ver_num =~ s/Version_(\d)\.0/v$1/x;

        my $fasta_file = join(".",$hgmi_sequence_dir,$short_ver_num,'contigs','newname', 'fasta');
    
        unless (defined($fasta_file)) 
        {
            croak "fasta-file: '$fasta_file' is not set! ";
        }
    
        if ((-z $fasta_file) ) 
        {
            croak "fasta-file: '$fasta_file 'is empty or non-existant!";
        }


        my $in = Bio::SeqIO->new(-file => $fasta_file, -format => 'Fasta');
    
        $sequence_set_obj = BAP::DB::SequenceSet->insert({
            sequence_set_name => $sequence_set_name,
            organism_id       => $organism_id,
        });
       
        $sequence_set_id = $sequence_set_obj->sequence_set_id();
    
        while (my $seq = $in->next_seq()) {
	
            my $sequence_obj = BAP::DB::Sequence->insert({
                sequence_set_id => $sequence_set_id,
                sequence_name   => $seq->display_id(),
                sequence_string => $seq->seq(),
            });
	
        }
	
        BAP::DB::DBI->dbi_commit();
    }

    unless (defined($sequence_set_id))
    {
        $sequence_set_id = $sequence_set_name_obj->sequence_set_id();
    }

    my @list =($organism_id,$sequence_set_name, $sequence_set_id);
    print join("\t",@list),"\n\n";

    my (
        $glimmer2_model,
        $glimmer3_model, $glimmer3_pwm,
        $genemark_model,
        $job_stdout, $job_stderr,
        $runner_count,
        $bappredictgenes_output
        );

    $glimmer2_model = $cwd."/Sequence/".$hgmi_locus_tag."_gl2.icm";

    if (-z $glimmer2_model) 
    {
        croak "glimmer2-model: '$glimmer2_model' is empty!";
    }

    $glimmer3_model = $cwd."/Sequence/".$hgmi_locus_tag."_gl3.icm";

    if (-z $glimmer3_model) 
    {
        croak "glimmer3-model: '$glimmer3_model ' is empty!";
    }

    $glimmer3_pwm   = $cwd."/Sequence/".$hgmi_locus_tag."_gl3.motif";

    if (-z $glimmer3_pwm) 
    {
        croak "glimmer3-pwm: '$glimmer3_pwm' is empty!";
    }

    my $model_file = undef;
    #my $model_file = <heu_11_*.mod>; # not being picked up

    my $idir = IO::Dir->new($cwd."/Sequence");
    while(defined(my $fname = $idir->read))
    {
        if($fname =~ /heu_11_(\d+).mod/)
        {
            $model_file = $fname;
        }
    }
    $idir->close;


    $genemark_model = $cwd."/Sequence/$model_file";


    if (-z $genemark_model) 
    {
        croak "genemark_model: '$genemark_model' is empty!";
    }

    unless (-f $genemark_model)
    {
        croak "genemark_model $genemark_model doesn't exist!";
    }

    $job_stdout     = $cwd."/".$hgmi_locus_tag."_bpg_BAP_job_".$sequence_set_id.".txt";

    $job_stderr     = $cwd."/".$hgmi_locus_tag."_bpg_BAP_job_err_".$sequence_set_id.".txt";

    $runner_count   = 50;

    $bappredictgenes_output = $cwd."/".$hgmi_locus_tag."_bpg_BAP_screenoutput_".$sequence_set_id.".txt";

    my $bsub_output = $cwd."/".$hgmi_locus_tag."_bpg_BAP_".$sequence_set_id.".output";

    my $bsub_error = $cwd."/".$hgmi_locus_tag."_bpg_BAP_".$sequence_set_id.".error";

    my $cmd;

    $cmd .= qq{(bsub -o $bsub_output -e $bsub_error -q long -n 2 -R 'span[hosts=1] rusage[mem=4096]' -N -u wnash\@wustl.edu \\\n};
    #$cmd .= qq{(bap_predict_genes --sequence-set-id $sequence_set_id --glimmer2-model $glimmer2_model \\\n};
           $cmd .= qq{bap_predict_genes --sequence-set-id $sequence_set_id --domain bacteria \\\n};
           $cmd .= qq{--glimmer3-model $glimmer3_model --glimmer3-pwm $glimmer3_pwm --genemark-model $genemark_model \\\n};
           $cmd .= qq{--runner-count $runner_count --job-stdout $job_stdout --job-stderr $job_stderr \\\n};
    #$cmd .= qq{) > & $bappredictgenes_output &\\\n};
           $cmd .= qq{) > & $bappredictgenes_output \\\n};

    print "bap_predict_genes.pl\n";
    print "\n$cmd \n";

    my @command_list = ($self->script_location,
                        '--sequence-set-id',
                        $sequence_set_id,
                        '--domain',
                        'bacteria',
                        '--glimmer3-model',
                        $glimmer3_model,
                        '--glimmer3-pwm',
                        $glimmer3_pwm,
                        '--genemark-model',
                        $genemark_model,
                        '--runner-count',
                        $runner_count,
                        '--job-stdout',
                        $job_stdout,
                        '--job-stderr',
                        $job_stderr
                        );
    if(defined($self->dev)) { push(@command_list,"--dev"); }
    return \@command_list;
}



1;

# $Id$
