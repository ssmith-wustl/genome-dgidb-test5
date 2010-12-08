package Genome::Model::Tools::Xhong::CopySnps;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Tools::Xhong::CopySnps {
	is => 'Command',
	has => [
    	somatic_build_id => { type => 'String', is_optional => 0, doc => "somatic build id to process", },
        analysis_dir => { type => 'String', is_optional => 1, doc => "Directory where the snp files should be, by default it will be in /gscmnt/sata843/info/medseq/data2SJC/", },
        force => { type => 'Boolean', is_optional => 1, default => 0, doc => "whether or not to directory exists, make new copy of snps files." ,
    },
        ]
};

sub help_brief {
    	"copy all snp files to make tar.gz to transfer to SJ"
}

sub help_detail {
    	<<'HELP';
Hopefully this script will run the ucsc annotator on indels and then tier them for an already completed somatic model. Since this is done in the data directory, the model is then reallocated.
HELP
}

sub execute {
	my $self=shift;
    	$DB::single = 1;
    	my $force = $self->force;
    	my $somatic_build_id=$self->somatic_build_id;
    	my $analysis_dir="/gscmnt/sata843/info/medseq/data2SJC";
    	my $build = Genome::Model::Build->get($somatic_build_id);
    	
    	my @snps_tiers;

        #satisfied we should start doing stuff here
        my $data_directory = $build->data_directory . "/";

       	unless(-d $data_directory) {
       		$self->error_message("$data_directory is not a directory");
       		return;
       	}

 #       my $indel_transcript_annotation = "$data_directory/annotate_output_indel.out";

	@snps_tiers=("hc1_tier1_snp_high_confidence.csv", "hc2_tier2_snp_high_confidence.csv", "hc3_tier3_snp_high_confidence.csv", "hc4_tier4_snp_high_confidence.csv","t1v_tier1_snp.csv", "t2v_tier2_snp.csv", "t3v_tier3_snp.csv", "t4v_tier4_snp.csv");
		
       	my $common_name = $build->tumor_build->model->subject->source_common_name;
	print "$common_name\n";
	my $user = getlogin || getpwuid($<); #get current user name
        	# submit samtool assembly for each tier of indels for a sample
       	my $snp_dir=$analysis_dir."/".$common_name."/".$common_name."_snps/";
       	my $sample_dir=$analysis_dir."/".$common_name;
       	unless (-d $snp_dir) {
       		$self ->error_message("$snp_dir exists, use --force");
       		return unless $force;
       	}
       	mkdir $sample_dir;
       	mkdir $snp_dir;
       	
       	foreach my $snp_file (@snps_tiers) {
       		`cp $data_directory/$snp_file $snp_dir/$snp_file`;
       	}
       	
       	sleep(2);
       	my $bz_file=$common_name."_snps.tbz";
       	my $bz_dir=$common_name."_snps";
       	
        chdir($sample_dir);
	`tar -cjvf $bz_file $bz_dir`;

        return 1;
}


1;


