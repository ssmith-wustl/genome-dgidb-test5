package Genome::Model::ReferenceAlignment::Command::MergeVcf;
use strict;
use warnings;
use Genome;
class Genome::Model::ReferenceAlignment::Command::MergeVcf {
    is => 'Command::V2',
    doc => 'Merge merged.vcf outputs from many samples into one vcf',
    has => [
        model_group => {
            is => 'Genome::ModelGroup',
            is_many => 1,
            shell_args_position => 1,
            doc => 'build to prepare',
        },
        snvs_output_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'Path to the snvs multi-sample merged vcf to output',
        },
        indels_output_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'Path to the indels multi-sample merged vcf to output',
        },
        use_gzipped_vcfs => {
            is => 'Boolean',
            doc => "Set this to operate on gzipped vcfs (and make them if they aren't there) and to output gzipped result",
            default => 0,
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
    unless($self->snvs_output_file || $self->indels_output_file){
        die $self->error_message("You must specify at least one output file!");
    }
    my $snvs_output_file = $self->snvs_output_file || undef;
    my $indels_output_file = $self->indels_output_file || undef;
    my @snv_list;
    my @indel_list;
    my @sample_list;
    if(-e $snvs_output_file){
        die $self->error_message("Output file already exists at: ".$snvs_output_file);
    }
    if(-e $indels_output_file){
        die $self->error_message("Output file already exists at: ".$indels_output_file);
    }
    my @mg = $self->model_group;
    my @input_vcfs; 

    my %inputs;
  
    #go through each model group and each model, pulling latest builds, checking for vcfs, and aggregating paths to them
    for my $mg (@mg) {
        for my $model ($mg->models){
            my $build = $model->last_succeeded_build;
            unless($build){
                $self->status_message("Skipping model: ".$model->id.". It no succeeded builds.");
                next;
            }
            my $sample = $model->subject->name;
            unless($sample){
                die $self->error_message("Could not find a sample name for model: ".$model->id);
            }
            if(exists($inputs{$sample})){
                die $self->error_message("Encountered multiple builds for one sample: ".$sample);
            }
            my $snvs_vcf = ($self->snvs_output_file) ? $build->get_snvs_vcf : undef;
            my $indels_vcf = ($self->indels_output_file) ? $build->get_indels_vcf : undef;

            if ($self->use_gzipped_vcfs) {
                if($snvs_vcf) {
                    unless($self->check_for_and_create_gz($build,$snvs_vcf)){
                        $self->status_message("Not including model: ".$model->id." as it had no snv vcf.");
                        next;
                    }
                }
                if($indels_vcf) {
                    unless($self->check_for_and_create_gz($build,$indels_vcf)){
                        $self->status_message("Not including model: ".$model->id." as it had no indel vcf.");
                        next;
                    }
                }
                push @snv_list, $build->get_snvs_vcf.".gz" if $snvs_output_file;
                push @indel_list, $build->get_indels_vcf.".gz" if $indels_output_file;
                
            } else {
                push @snv_list, $build->get_snvs_vcf if $snvs_output_file;
                push @indel_list, $build->get_indels_vcf if $indels_output_file;
            }

            push @sample_list, $sample."\t".$build->id;
        }
    }
    my $gzip = $self->use_gzipped_vcfs || 0;
    if($snvs_output_file){
        my $join_cmd = Genome::Model::Tools::Joinx::VcfMerge->create(
            output_file => $snvs_output_file,
            input_files => \@snv_list,
            use_bgzip => $gzip,
            joinx_bin_path => "/gscmnt/ams1158/info/pindel/joinx/joinx",
        );

        unless($join_cmd->execute){
            die $self->error_message("Could not execute MultiSampleJoinVcf command!");
        }

        unless(-s $snvs_output_file){
            die $self->error_message("Could not find output file!");
        } 
    }
    if($indels_output_file){
        my $join_cmd = Genome::Model::Tools::Joinx::VcfMerge->create(
            output_file => $indels_output_file,
            input_files => \@indel_list,
            use_bgzip => $gzip,
            joinx_bin_path => "/gscmnt/ams1158/info/pindel/joinx/joinx",
        );

        unless($join_cmd->execute){
            die $self->error_message("Could not execute MultiSampleJoinVcf command!");
        }

        unless(-s $indels_output_file){
            die $self->error_message("Could not find output file!");
        } 
    }
    return 1;
}

#if the vcf is not gzipped and indexed for tabix, do so and reallocate the host build
sub check_for_and_create_gz {
    my $self = shift;
    my $build = shift;
    my $merged_vcf = shift;
    #my $merged_vcf = $build->get_merged_vcf;
    my $merged_vcf_gz = $merged_vcf.".gz";
    my $merged_vcf_gz_tbi = $merged_vcf_gz.".tbi";
    my $changes = undef;
    unless(-e $merged_vcf_gz){
        unless(-e $merged_vcf){
            die $self->error_message("Could not locate merged VCF at: ".$merged_vcf);
        }
        my $cmd = "bgzip -c ".$merged_vcf." > ".$merged_vcf_gz;
        Genome::Sys->shellcmd( cmd => $cmd);
        unless(-e $merged_vcf_gz){
            die $self->error_message("Tried to create gzipped merged vcf, but failed.");
        }
        $changes = 1;
    }
    unless(-e $merged_vcf_gz_tbi){
        my $tbi_cmd = "tabix -p vcf ".$merged_vcf_gz;
        unless(Genome::Sys->shellcmd( cmd => $tbi_cmd)){
            die $self->error_message("Could not create tabix index file for: ".$merged_vcf_gz);
        }
        unless(-e $merged_vcf_gz_tbi ){
            die $self->error_message("Could not create tabix index file for: ".$merged_vcf_gz);
        }
        $changes = 1;
    }
    if($changes){
        #$self->_needs_commit(1);
        my $build_allocation = $build->disk_allocation;
        $build_allocation->reallocate;
        UR::Context->commit;
    }
    return 1;
}

1;
