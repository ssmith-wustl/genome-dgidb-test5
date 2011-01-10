package Genome::Model::Tools::Xhong::TestDnp;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Xhong::TestDnp {
    is => 'Command',
    has => [
    build_ids => { 
        type => 'String',
        is_optional => 1,
        doc => "build ids of the build to process. comma separated",
    },
    model_group_name => {
        type => 'String',
        is_optional => 1,
        doc => 'model-group containing only somatic models. Current running builds will be used if no successful build is available',
    },
    analysis_dir=> {
     	type => 'String',
        is_optional => 1,
        doc => 'where the output file will be written to',
    }
    ]
};


sub execute {
    my $self=shift;
    $DB::single = 1;
    my @builds;
    
    if($self->build_ids) {
        @builds = map { Genome::Model::Build->get($_) } split /,/, $self->build_ids;
    }
    elsif($self->model_group_name) {
        my $group = Genome::ModelGroup->get(name => $self->model_group_name);
        @builds = grep { defined $_ } map {$_->last_succeeded_build ? $_->last_succeeded_build : $_->current_running_build ? $_->current_running_build : undef } $group->models;
    }

    foreach my $build (@builds) {
        
        my $model = $build->model;
        unless(defined($model)) {
            $self->error_message("Somehow this build does not have a model");
            return;
        }
        unless($model->type_name eq 'somatic') {
            $self->error_message("This build must be a somatic pipeline build");
            return;
        }
	my $analysis_dir=$self->analysis_dir;
	my $data_directory = $build->data_directory;
	
        my $tumor_build = $build->tumor_build;
        my $normal_build = $build->normal_build;

        my $common_name = $build->tumor_build->model->subject->source_common_name;
        my $tumor_bam = $build->tumor_build->whole_rmdup_bam_file;
        my $normal_bam = $build->normal_build->whole_rmdup_bam_file;

        my $input_snp_file = $data_directory."/dbsnp_filtered.csv";
        my $dnp_output_file=$analysis_dir."/".$common_name."/dnp_out.csv";
	my $dnp_bed_file=$analysis_dir."/".$common_name."/dnp_out_bed.csv";
#	my $tiered_bed_file=$analysis_dir."/".$common_name."/fast-tier/dnp_out_bed.csv";
        my $dnp_anno =$dnp_output_file.".anno";
        my $dnp_ucsc_anno =$dnp_output_file.".anno.ucsc";
        my $dnp_ucsc_unanno =$dnp_output_file.".anno.ucsc.unanno";
        print "\n\n$common_name\n";
        my $cmd= `bsub -J $common_name.dnp -R \'select[type==LINUX64]\' \'perl -I /gscuser/xhong/git/genome/lib/perl \`which gmt\` somatic identify-dnp-adv --annotation-input-file=$input_snp_file --bam-file=$tumor_bam --anno-file $dnp_output_file --bed-file $dnp_bed_file\'`;
print "$cmd\n";
	my ($jobid1) = ($cmd =~ m/<(\d+)>/);

# testA: for traditional annotation and tiering are succeed, skip...."

#	my $job1=print `bsub -J $common_name.anno 'perl -I /gscuser/xhong/git/genome/lib/perl/ \`which gmt\` annotate transcript-variants --variant-file $dnp_output_file --output-file $dnp_anno --annotation-filter top'`;
#	$job1=~/<(\d+)>/;
#	my $job2=print `bsub -J $common_name.ucsc 'perl -I /gscuser/xhong/git/genome/lib/perl/ \`which gmt\` somatic ucsc-annotator --input-file=$input_snp_file  --output-file=$dnp_ucsc_anno --unannotated-file=$dnp_ucsc_unanno'`;
#	$job2=~/<(\d+)>/;
#	$cmd="bsub -J $common_name.tier -w \'ended($job1) && ended($job2)\' \'perl -I /gscuser/xhong/git/genome/lib/perl/ \`which gmt\` somatic tier-variants --variant $dnp_output_file --transcript $dnp_anno --ucsc-file $dnp_ucsc_anno --tier1-file $dnp_output_file.tier1 --tier2-file $dnp_output_file.tier2 --tier3-file $dnp_output_file.tier3 --tier4-file $dnp_output_file.tier4\'";
#	print `$cmd`;

# testB: for bed file and fast-tiering, this is new and on going"
#	my $pwd=`pwd`;
#	system("cd $analysis_dir/fast-tier");

	$cmd=print `bsub -J $common_name.fast-tier -w \'ended($jobid1)\' 'perl -I /gscuser/xhong/git/genome/lib/perl \`which gmt\` fast-tier fast-tier --variant-bed-file $dnp_bed_file --exclusive-tiering'`;
	my$jobid2 = ($cmd =~ m/<(\d+)>/);
	$cmd=print `bsub -J $common_name.anno.T1 -w \'ended($jobid1) && ended($jobid2)\' 'perl -I /gscuser/xhong/git/genome/lib/perl/ \`which gmt\` annotate transcript-variants --variant-bed-file $dnp_bed_file.tier1 --output-file $dnp_bed_file.tier1.anno --annotation-filter top'`;
	$cmd=print `bsub -J $common_name.anno.T2 -w \'ended($jobid1) && ended($jobid2)\' 'perl -I /gscuser/xhong/git/genome/lib/perl/ \`which gmt\` annotate transcript-variants --variant-bed-file $dnp_bed_file.tier2 --output-file $dnp_bed_file.tier2.anno --annotation-filter top'`;
	$cmd=print `bsub -J $common_name.anno.T3 -w \'ended($jobid1) && ended($jobid2)\' 'perl -I /gscuser/xhong/git/genome/lib/perl/ \`which gmt\` annotate transcript-variants --variant-bed-file $dnp_bed_file.tier3 --output-file $dnp_bed_file.tier3.anno --annotation-filter top'`;
	$cmd=print `bsub -J $common_name.anno.T4 -w \'ended($jobid1) && ended($jobid2)\' 'perl -I /gscuser/xhong/git/genome/lib/perl/ \`which gmt\` annotate transcript-variants --variant-bed-file $dnp_bed_file.tier4 --output-file $dnp_bed_file.tier4.anno --annotation-filter top'`;	

    }
    return 1; 

}


1;

sub help_brief {
    "Give the bam files of somatic builds"
}

sub help_detail {
    <<'HELP';
This test if the depended other scripts in the somatic pipeline can fit the input/output produced by IdentifyDnp.pm
HELP
}
