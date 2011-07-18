package Genome::Model::ReferenceAlignment::Command::PrepareTumorOnlyBuild;

class Genome::Model::ReferenceAlignment::Command::PrepareTumorOnlyBuild {
    is => 'Command::V2',
    doc => 'Add dbsnp filtering for results of refalign build on tumor only model',
    has => [
        build => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            shell_args_position => 1,
            doc => 'build to prepare',
        },
        dbsnp_build => {
            is => 'Genome::Model::Build::ImportedVariationList',
            doc => 'dbSNP build to filter on, if not given, will use dbSNP build from the build input',
            is_optional => 1,
        },
        bed_version => {
            is => 'Text',
            doc => 'Version of bed file to require.',
            default => '2',
        },
    ],
};

sub help_detail {
    return <<EOS 
PrepareTumorOnlyBuild is a script which is meant to be run on a reference-alignment build with a completed
detect-variants step. This script will pull the snvs and indels then create a ./effects subdir on the build's
data-directory. This script then splits the snvs into dbSNP and novel, based on either the dbsnp_build param
or the dbsnp_build param on the refalign build passed in.
EOS
}

sub execute {
    my $self = shift;

    #reference alignment build object    
    my $build = $self->build;

    #get the appropiate dbSNP build
    my $dbsnp_build = defined($self->dbsnp_build) ? $self->dbsnp_build : $build->dbsnp_build;
    my $dbsnp_feature_list =  $dbsnp_build->snv_feature_list;
    my $dbsnp_file = $dbsnp_feature_list->file_path;
    unless(defined($dbsnp_build)){
        $self->status_message("No dbsnp build found, nothing to do. Exiting.");
        return 1;
    }

    my $build_dir = $build->data_directory;
    my $version = $self->bed_version;
    my $snv_bed_file = $build_dir."/variants/snvs.hq.v".$version.".bed";

    unless(-e $snv_bed_file){
        die $self->error_message("Could not locate snvs file at: ".$snv_bed_file."\n");
    }

    my $output_dir = $build_dir."/effects";
    my $in_dbsnp_file = $output_dir."/snvs.hq.previously_detected.v".$version.".bed";
    my $novel_file = $output_dir."/snvs.hq.novel.v".$version.".bed";
    my $indel_file = $build_dir."/variants/indels.hq.v".$version.".bed";

    my $annotation_build = $build->annotation_reference_build;
    my $tier_file_location = $annotation_build->tiering_bed_files_by_version(2);
    unless(defined($tier_file_location)){
        die $self->error_message("Could not locate tiering files!");
    }
    my $indel_input = $output_dir."/indels.hq.novel.v".$version.".bed";

    #create the output directory 
    unless(-d $output_dir){
        Genome::Sys->create_directory($output_dir);
    }

    #run dbSNP intersection
    unless(-e $novel_file && -e $in_dbsnp_file){
        my $dbsnp_intersection = Genome::Model::Tools::Joinx::Intersect->create(
            input_file_a => $snv_bed_file,
            input_file_b => $dbsnp_file,
            miss_a_file => $novel_file,
            output_file => $in_dbsnp_file,
            dbsnp_match => 1,
        );
        unless ($dbsnp_intersection){
            die $self->error_message("Couldn't create joinx intersection tool!");
        }
        my $snv_rv = $dbsnp_intersection->execute();
        my $snv_err = $@;
        unless ($snv_rv){
            die $self->error_message("Failed to execute joinx intersection (err: $snv_err )");
        }
    }

    #copy indels from ./variants to ./effects, novel, since there are as yet no dbSNP indel intersections
    unless(-e $indel_input){
        Genome::Sys->copy_file($indel_file,$indel_input);
    }    

    #compose snv and indel tiering output file names
    my @snv_tiers = map{ "snvs.hq.novel.tier".$_.".v".$version.".bed"} (1..4);
    my @indel_tiers = map{ "indels.hq.novel.tier".$_.".v".$version.".bed"} (1..4);
    my $snv_files_present=1;
    for (1..4) {
        my $f = -e $output_dir."/".$snv_tiers[$_];   
        $snv_files_present = $snv_files_present && $f;
    }

    #tier snvs
    unless( $snv_files_present ){
        my $snv_tier_cmd = Genome::Model::Tools::FastTier::FastTier->create(
            variant_bed_file => $novel_file,
            tier_file_location => $tier_file_location,
            tier1_output => $output_dir."/".$snv_tiers[0],
            tier2_output => $output_dir."/".$snv_tiers[1],
            tier3_output => $output_dir."/".$snv_tiers[2],
            tier4_output => $output_dir."/".$snv_tiers[3],
        );
        unless($snv_tier_cmd){
            die $self->error_message("Could not create tiering command for snvs!");
        }
        unless($snv_tier_cmd->execute){
            die $self->error_message("Tiering Snvs did not succeed!");
        }
    }
    my $indel_files_present=1;
    for (1..4) {
        my $f = -e $output_dir."/".$indel_tiers[$_];   
        $indel_files_present = $indel_files_present && $f;
    }

    #tier indels
    unless( $indel_files_present ){
        my $indel_tier_cmd = Genome::Model::Tools::FastTier::FastTier->create(
            variant_bed_file => $indel_input,
            tier_file_location => $tier_file_location,
            tier1_output => $output_dir."/".$indel_tiers[0],
            tier2_output => $output_dir."/".$indel_tiers[1],
            tier3_output => $output_dir."/".$indel_tiers[2],
            tier4_output => $output_dir."/".$indel_tiers[3],
        );
        unless($indel_tier_cmd){
            die $self->error_message("Could not create tiering command for indels!");
        }
        unless($indel_tier_cmd->execute){
            die $self->error_message("Tiering Indels did not succeed!");
        }
    }

    #prepare annotation output file names
    my $snv_tier1_anno_output = $output_dir."/snvs.hq.novel.tier1.annotated";
    my $snv_tier2_anno_output = $output_dir."/snvs.hq.novel.tier2.annotated";
    my $indel_tier1_anno_output = $output_dir."/indels.hq.novel.tier1.annotated";
    my $indel_tier2_anno_output = $output_dir."/indels.hq.novel.tier2.annotated";

    # Annotate Variants

    unless((-e $snv_tier1_anno_output && -e $snv_tier2_anno_output) &&
           (-e $indel_tier1_anno_output && -e $indel_tier2_anno_output)){

        #Annotate Snvs
        my $snv_tier1_anno_cmd = Genome::Model::Tools::Annotate::TranscriptVariants->create(
            variant_bed_file => $output_dir."/".$snv_tiers[0],
            output_file => $snv_tier1_anno_output,
            annotation_filter => "top",
            build_id => $annotation_build->id,
            use_version => 2,
        );
        unless($snv_tier1_anno_cmd){
            die $self->error_message("Could not create snv_tier1_anno_cmd!");
        }
        unless($snv_tier1_anno_cmd->execute){
            die $self->error_message("Could not complete snv_tier1_anno_cmd");
        }
        my $snv_tier2_anno_cmd = Genome::Model::Tools::Annotate::TranscriptVariants->create(
            variant_bed_file => $output_dir."/".$snv_tiers[1],
            output_file => $snv_tier2_anno_output,
            annotation_filter => "top",
            build_id => $annotation_build->id,
            use_version => 2,
        );
        unless($snv_tier2_anno_cmd){
            die $self->error_message("Could not create snv_tier1_anno_cmd!");
        }
        unless($snv_tier2_anno_cmd->execute){
            die $self->error_message("Could not complete snv_tier1_anno_cmd");
        }

        #Annotate Indels
        my $indel_tier1_anno_cmd = Genome::Model::Tools::Annotate::TranscriptVariants->create(
            variant_bed_file => $output_dir."/".$indel_tiers[0],
            output_file => $indel_tier1_anno_output,
            annotation_filter => "top",
            build_id => $annotation_build->id,
            use_version => 2,
        );
        unless($indel_tier1_anno_cmd){
            die $self->error_message("Could not create indel_tier1_anno_cmd!");
        }
        unless($indel_tier1_anno_cmd->execute){
            die $self->error_message("Could not complete indel_tier1_anno_cmd");
        }
        my $indel_tier2_anno_cmd = Genome::Model::Tools::Annotate::TranscriptVariants->create(
            variant_bed_file => $output_dir."/".$indel_tiers[1],
            output_file => $indel_tier2_anno_output,
            annotation_filter => "top",
            build_id => $annotation_build->id,
            use_version => 2,
        );
        unless($indel_tier2_anno_cmd){
            die $self->error_message("Could not create indel_tier1_anno_cmd!");
        }
        unless($indel_tier2_anno_cmd->execute){
            die $self->error_message("Could not complete indel_tier1_anno_cmd");
        }
    }

    #reallocate build's data_directory since we have added some data
    my $build_allocation = $build->disk_allocation;
    $build_allocation->reallocate;
    return 1;
}

1;
