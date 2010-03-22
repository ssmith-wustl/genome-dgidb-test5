package Genome::Model::Tools::Cmds::CompileCnaOutput;

use warnings;
use strict;
use Genome;

class Genome::Model::Tools::Cmds::CompileCnaOutput {
    is => 'Command',
    has => [
    model_ids => {
        type => 'String',
        is_optional => 0,
        doc => 'Somatic build ids to check for CNA output (space delimited).'
    },
    ]
};

sub help_brief {
    'This script checks for "copy_number_output.out" and "copy_number_output.out.png" in somatic builds, and then generates a symbolic link to them if they exist. If they do not exist, the script will submit jobs to run the bam-to-cna script. Messages will indicate the status of the builds and actions taken, and the std_out of the submitted jobs will be printed in the working directory, so that you will be able to see their status and somatic model_ids associated. You will want to run this script again to create the missing symbolic links when all of your builds have the appropriate copy_number_output files.'
}

sub help_detail {
    'This script checks for "copy_number_output.out" and "copy_number_output.out.png" in somatic builds, and then generates a symbolic link to them if they exist. If they do not exist, the script will submit jobs to run the bam-to-cna script. Messages will indicate the status of the builds and actions taken, and the std_out of the submitted jobs will be printed in the working directory, so that you will be able to see their status and somatic model_ids associated. You will want to run this script again to create the missing symbolic links when all of your builds have the appropriate copy_number_output files.'
}

sub execute {
    my $self = shift;
    my @model_ids = split /\s+/,$self->model_ids;

    for my $somatic_model_id (@model_ids) {
        my $somatic_model = Genome::Model->get($somatic_model_id) or die "No somatic model found for id $somatic_model_id.\n";
        my $somatic_build = $somatic_model->last_succeeded_build or die "No succeeded build found for somatic model id $somatic_model_id.\n";
        my $somatic_build_id = $somatic_build->id or die "No build id found in somatic build object for somatic model id $somatic_model_id.\n";
        print "Last succeeded build for somatic model $somatic_model_id is build $somatic_build_id. ";
        my $cn_data_file = $somatic_build->somatic_workflow_input("copy_number_output") or die "Could not query somatic build for copy number output.\n";
        my $cn_png_file = $cn_data_file . ".png";

        #if files are found (bam-to-cna has been run correctly already), create link to the data in current folder
        if (-s $cn_data_file && -s $cn_png_file) {
            my $link_name = $somatic_model_id . ".copy_number.csv";
            `ln -s $cn_data_file $link_name`;
            print "Link to copy_number_output created.\n";
        }
        else {
            #get tumor and normal bam files
            print "Copy number output not found for build $somatic_build_id. ";
            my $tumor_build = $somatic_build->tumor_build or die "Cannot find tumor model.\n";
            my $normal_build = $somatic_build->normal_build or die "Cannot find normal model.\n";
            my $tumor_bam = $tumor_build->whole_rmdup_bam_file or die "Cannot find tumor .bam.\n";
            my $normal_bam = $normal_build->whole_rmdup_bam_file or die "Cannot find normal .bam.\n";

            #run bam-2-cna
            my $job = "gmt somatic bam-to-cna --tumor-bam-file $tumor_bam --normal-bam-file $normal_bam --output-file $cn_data_file";
            my $job_name = $somatic_model_id . "_bam2cna";
            my $oo = $job_name . "_stdout"; #print job's STDOUT in the current directory
            print "Submitting job $job_name (bam-to-cna).\n";
            LSF::Job->submit(-q => 'long', -J => $job_name, -R => 'select[type==LINUX64]', -oo => $oo, "$job");
        }
    }   
    return 1;
}
1;
