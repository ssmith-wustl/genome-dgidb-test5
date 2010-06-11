package Genome::Model::Tools::Xhong::CompareSnpsBuildLanes;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Genome::Model::InstrumentDataAssignment;

class Genome::Model::Tools::Xhong::CompareSnpsBuildLanes {
    is => 'Command',
    has => [
    build_id => { 
        type => 'String',
        is_optional => 1,
        doc => "build id of the build to gather metrics for",
    },
    model_id => { 
        type => 'String',
        is_optional => 1,
        doc => "somatic model id to get the last suceed build to gather metrics for",
    },
    analysis_dir => {
        type => 'String',
        is_optional => 0,
        doc => "Directory to use for maplists and mapcheck output",
    },
    genotype_file => {
        type => 'String',
        is_optional => 1,
        doc => "Genotype file to use as input to gmt analysis lane-qc compare-snps",
    },
    sample_name => {
    	type => 'String',
    	is_optional => 1,
    	doc => "Sample name to get imported genotype file, for example H_LC-SJTALL001-G-TB-01-1378 ",
    },
    ]
};


sub execute {
    my $self=shift;
    $DB::single = 1;
    my $build_id = "";
    $build_id = $self->build_id;
    my $tumorornormal_model_id = $self->model_id;
#    print "$somatic_model_id, $somatic_model, $build_status";
#    return;
    
    # step1 : to find genotype file or return;
    my $genotype_file = $self->genotype_file;
    my $sample_name = $self->sample_name;
    if ($sample_name ne ""){
    # get owner_id of the microarray_genotype file
    	system("genome instrument-data list imported --filter sample_name=$sample_name --noheader | cut -d ' ' -f1 > /tmp/$sample_name");
    	open (FH, "/tmp/$sample_name");
    	my @owner_id=<FH>;
    	my $owner_id=$owner_id[0];
    	$owner_id=~s/\s+//;
    	print $owner_id;
    	close FH;
    # get the path of genotype file
    	system("genome disk allocation list  --noheader --filter owner_id=$owner_id | cut -d ' ' -f1 > /tmp/$sample_name.path");
    	open (FH2, "/tmp/$sample_name.path"); 
    	my @path=<FH2>;
    	my $path=$path[0];
    	$path=~s/\s+//;
    	my $find_genotype_file=$path."/".$sample_name.".genotype";
    	print "\n$find_genotype_file\n";
    	close FH2;
    	system("rm /tmp/$sample_name");
    	system("rm /tmp/$sample_name.path");
    # check if genotype_file exists
    	unless(-e $find_genotype_file || -e $genotype_file){
    		$self->error_message("Unable to file genotype file $find_genotype_file and $genotype_file\n please check and supply path to --genotype-file");
		return;
	}		
        if (-e $find_genotype_file ){
		$genotype_file=	$find_genotype_file;
	}
    }else{
    	$self->error_message("Need to have --sample_name or --genotype-file, use -h for additional info");
    	return;
    }

    # step2: To find alignment file of the build or return;
    # can be improved to use somatic model-id and grap the last succeed build to fine the alignment files
    
    # Step2: to get the somatic model and its last succeed build
    my $tumorornormal_model;
    my $build;
    unless ( $build_id ne ""){
	$tumorornormal_model = Genome::Model-> get(genome_model_id =>$tumorornormal_model_id);
	$build= $tumorornormal_model->last_succeeded_build;
	$build_id=$build->build_id;
    }
    
    # find build
#    my $build = Genome::Model::Build->get($build_id);
    unless(defined($build)){
        $self->error_message("Unable to find build $build_id");
        return;
    }
    #find model

#    my $model = $build->model;
    my $model=$tumorornormal_model;
    unless(defined($model)) {
        $self->error_message("Somehow this build does not have a model");
        return;
    }
    
    printf STDERR "Grabbing information for model %s (build %s)\n", $model->name, $build->build_id;       
    #Grab all alignment events so we can filter out ones that are still running or are abandoned
    # get all align events for the current running build
    my @align_events = Genome::Model::Event->get(event_type => 
        {operator => 'like', value => '%align-reads%'},
        build_id => $build,
        model_id => $model->id,
    );
    printf STDERR "%d lanes in build\n", scalar(@align_events);
    #now just get the Succeeded events to pass along for further processing
    # THIS MAY NOT INCLUDE ANY EVENTS
    my @events = Genome::Model::Event->get(event_type => 
        {operator => 'like', value => '%align-reads%'},
        build_id => $build,
        event_status => 'Succeeded',
        model_id => $model->id,

    );
    # if it does not include any succeeded events - die
    unless (@events) {
        $self->error_message(" No alignments have Succeeded on the build ");
        return;
    }
    printf STDERR "Using %d lanes to calculate metrics\n", scalar(@events);
    #Convert events to InstrumentDataAssignment objects
	my @idas = $build->instrument_data_assignments;
#	my $reference_file="/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa"; 
	my $reference_file=$model->reference_sequence_build->full_consensus_path('fa') ;
	my $dir = $self->analysis_dir;
	my $login = getlogin || getpwuid($<); #get current user name	 
	print "reference: $reference_file User: $login";
	return;
	for my $ida (@idas) {
		my @alignments = $ida->results($build);
		for my $alignment (@alignments) {
     		        my $instrument_data = $alignment->instrument_data;
     	        	my $lane=$instrument_data->lane;
	     	        my $flow_cell_id=$instrument_data->flow_cell_id;
			my $lane_name="$flow_cell_id"."_"."$lane";	
     			my @bam = $alignment->alignment_bam_file_paths;
     			my $alignment_file = $bam[0];
			if ($alignment_file ne ""){
		        	$self->error_message("test: $lane_name");		        
		        	$self->error_message("bam: $alignment_file");
				unless(-e $alignment_file) {
					$self->error_message("$alignment_file does not exist");
					return;
		        	}
		        	my $command .= <<"COMMANDS";
samtools pileup -vc -f $reference_file $alignment_file | perl -pe '\@F = split /\\t/; \\\$_=q{} unless(\\\$F[7] > 2);' > $dir/$lane_name.var
gmt analysis lane-qc compare-snps --genotype-file $genotype_file --variant-file $dir/$lane_name.var > $dir/$lane_name.var.compare_snps
COMMANDS
print `bsub -N -u xhong\@genome.wustl.edu -R 'select[type==LINUX64]' "$command"`;
			}else{
				$self->error_message("No alignment object for $lane_name");
				return;
			}
		}	
	}
    return 1;
}

1;

sub help_brief {
    "Generates mapcheck data on every lane in a build"
}

sub help_detail {
    <<'HELP';
This script runs maq mapcheck on every lane in a build. The hope is that this can then be used to easily assemble lanes into a model of a given haploid coverage. It may also be useful for analysis of quality metrics on a per lane basis.
HELP
}
