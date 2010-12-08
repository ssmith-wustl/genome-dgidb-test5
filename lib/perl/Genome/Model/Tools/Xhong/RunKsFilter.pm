package Genome::Model::Tools::Xhong::RunKsFilter;

use strict;
use warnings;

use Genome;
use IO::File;


class Genome::Model::Tools::Xhong::RunKsFilter {
	is => 'Command',
	has => [
	somatic_build_id => { type => 'String', is_optional => 0, doc => "the somatic build_id to process.", },
    	goldsnp_file=> { type => 'String', is_optional => 1, doc => "the corrresponding tumor gold snp file for the somatic build",},
        analysis_dir => { type => 'String', is_optional => 0, doc => "Directory where the filtered SNVs output will be", },
        ]
};

sub help_brief {
    	"Generates ks filtered SNVs and its annotation for the last succeed builds for a somatic model"
}

sub help_detail {
    	<<'HELP';
Hopefully this script run ks filter on the last succeed somatic builds in a model group
HELP
}

sub execute {
	my $self=shift;
    	$DB::single = 1;
    	my $goldsnp_file;
    	unless ($self->goldsnp_file){
    		$goldsnp_file="";
    	}
    	my $analysis_dir=$self->analysis_dir;
    	my $somatic_build_id =$self->somatic_build_id;
    	unless ($somatic_build_id){
    		$self->error_message("must have either somatic-build-id");
    		return;
    	}
    	my $build = Genome::Model::Build->get($somatic_build_id);
        unless(defined($build)) {
        $self->error_message("Unable to find build $somatic_build_id");
        return;
	}
    	my $model = $build->model;
    	unless(defined($model)) {
        	$self->error_message("Somehow this build does not have a model");
	        return;
    	}
    	unless($model->type_name eq 'somatic') {
        	$self->error_message("This build must be a somatic pipeline build");
        	return;
    	}
    	my $data_directory = $build->data_directory;
        unless(-d $data_directory) {
        	$self->error_message("$data_directory is not a directory");
        	return;
        }
        	
	my $common_name = $build->tumor_build->model->subject->source_common_name;

	my $user = getlogin || getpwuid($<); #get current user name
	my $out_dir=$analysis_dir."/".$common_name."_ksfiltered/";
# check whether the directory can be created or already exists		
	unless (-d "$out_dir"){
        	system ("mkdir -p $out_dir");
        }
       	my $cmd ="";
        if ($goldsnp_file eq ""){
        	$cmd ="bsub -N -u $user\@genome.wustl.edu -J $common_name.KS -R \'select\[type==LINUX64\]\' \'gmt somatic ks-filter --output-data-dir=$out_dir --somatic-build-id=$somatic_build_id\'";
       	}else{
       		$cmd ="bsub -N -u $user\@genome.wustl.edu -J $common_name.KS -R \'select\[type==LINUX64\]\' \'perl -I /gscuser/xhong/git/genome/lib/perl/ \`which gmt\` somatic ks-filter-gold --gold-snp-file=$goldsnp_file --output-data-dir=$out_dir ----somatic-build-id=$somatic_build_id\'"
        }
        my $bjobs= `$cmd`;
       	$bjobs =~ /<(\d+)>/;
	$bjobs=$1;
	
       	my $variant_file = $out_dir."/hf1_tier1_filtered_snp_high_confidence.csv";
       	my $variant_file_before = $out_dir."/hf1_tier1_filtered_snp_high_confidence.csvbefore";
       	$cmd="awk \'{print $1\"\\t\"$2\"\\t\"$2\"\\t\"$3\"\\t\"$4}\' $variant_file > $variant_file_before";
       	my $bjob2=`bsub -b '2:0' $cmd`;
       	my $cmd_anno =printf("cd ~/genome-stable && bsub -N -u $user\@genome.wustl.edu -w 'ended($bjob2)' -J $common_name.KS.anno -R 'select\[type==LINUX64\]' 'gmt annotate transcript-variants --variant-file $variant_file_before --output-file $variant_file.anno --annotation-filter top");
       	system($cmd);

        return 1;
}


1;


