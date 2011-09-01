package Genome::Model::ReferenceAlignment::Command::MergeVcf;

class Genome::Model::ReferenceAlignment::Command::MergeVcf {
    is => 'Command::V2',
    doc => 'Merge merged.vcf outputs from many samples into one vcf',
    has => [
        model_group => {
            is => 'Genome::ModelGroup',
            shell_args_position => 1,
            doc => 'build to prepare',
        },
        output_file => {
            is => 'Text',
            doc => 'Path to the multi-sample merged vcf to output',
        },
    ],
};

sub help_detail {
    return <<EOS 
    Use this to merge VCF's from multiple reference-alignments into one 
EOS
}

sub execute {
    my $self = shift;

    #reference alignment build object    
    my $mg = $self->model_group;
    my @input_vcfs; 
    for my $model ($mg->models){
        my $build = $model->last_succeeded_build;
        unless($build){
            $self->status_message("Skipping model: ".$model->id.". It no succeeded builds.");
            next;
        }
        unless($self->check_for_and_create_gz($build)){
            $self->status_message("Not including model: ".$model->id." as it had no merged vcf.");
            next;
        }
        push @input_vcfs, $build->get_merged_vcf.".gz";
    }

    my $output_file = $self->output_file;

    #TODO  Right now this just merges them all at once... this might be painful when there are many files...
    my $multi_sample_merge = "vcf-merge ".join(" ",@input_vcfs)." | bgzip -c > ".$output_file;
    unless(Genome::Sys->shellcmd(cmd => $multi_sample_merge)){
        die $self->error_message("vcf-merge command line call failed!");
    }
    unless(-s $output_file){
        die $self->error_message("Could not find output file!");
    } 
    return 1;
}

sub check_for_and_create_gz {
    my $self = shift;
    my $build = shift;
    my $merged_vcf = $build->get_merged_vcf;
    my $merged_vcf_gz = $merged_vcf.".gz";
    my $merged_vcf_gz_tbi = $merged_vcf_gz.".tbi";
    unless(-e $merged_vcf_gz){
        unless(-e $merged_vcf){
            die $self->error_message("Could not locate merged VCF at: ".$output_dir);
        }
        my $cmd = "bgzip -c ".$merged_vcf." > ".$merged_vcf_gz;
        Genome::Sys->shellcmd( cmd => $cmd);
        unless(-e $merged_vcf_gz){
            die $self->error_message("Tried to create gzipped merged vcf, but failed.");
        }
    }
    unless(-e $merged_vcf_gz_tbi){
        my $tbi_cmd = "tabix -p vcf ".$merged_vcf_gz;
        unless(Genome::Sys->shellcmd( cmd => $tbi_cmd)){
            die $self->error_message("Could not create tabix index file for: ".$merged_vcf_gz);
        }
        unless(-e $merged_vcf_gz_tbi ){
            die $self->error_message("Could not create tabix index file for: ".$merged_vcf_gz);
        }
    }
    if($changes){
        $self->_needs_commit(1);
        my $build_allocation = $build->disk_allocation;
        $build_allocation->reallocate;
        UR::Context->commit;
    }
    return 1;
}


1;
