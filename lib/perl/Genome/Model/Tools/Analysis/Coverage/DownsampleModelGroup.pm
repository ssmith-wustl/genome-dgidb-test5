package Genome::Model::Tools::Analysis::Coverage::DownsampleModelGroup;
use strict;
use warnings;
use FileHandle;
use Genome;

my %stats = ();

class Genome::Model::Tools::Analysis::Coverage::DownsampleModelGroup {
	is => 'Command',                       
	has => [
		group_id => {
                    is => 'Text',
                    doc => "ID of model group",
                    is_optional => 0
                },
		output_directory => {
                    is => 'Text',
                    doc => "Directory into which all results will be placed",
                    is_optional => 0
                },
                coverage_in_gb => {
                    is => 'Text',
                    doc => "Comma-delimited set to pass to downsampling script, in GB. 1.5 = 1,500,000,000 bases. Set this or ratio, not both.",
                    is_optional => 1,
                    is_input => 1,
                },
                coverage_ratio => {
                    is => 'Text',
                    doc => "Comma-delimited set to pass to downsampling script, units should be 0 to 1, where 1 = 100% = whole bam. Set this or gb, not both.",
                    is_optional => 1,
                    is_input => 1,
                },
                random_seed => {
                    is => 'Text',
                    doc => 'Set this equal to the reported random seed to reproduce previous results',
                    is_optional => 1,
                },
                processing_profile_id => {
                    is => 'Text',
                    doc => 'Set this equal to the reported random seed to reproduce previous results',
                    is_optional => 1,
                    default => 2646038,
                },


	],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Operate on capture somatic model groups"                 
}

sub help_synopsis {
    return help_brief()."\nEXAMPLE: gmt capture somatic-model-group --group-id 3328";
}

sub execute {
    my $self = shift;

    unless($self->coverage_in_gb xor $self->coverage_ratio){
        $self->error_message("You must either specify coverage_in_gb or coverage_ratio, not both.");
        die $self->error_message;
    }

    my $outdir = $self->output_directory;
    my $processing_profile_id = $self->processing_profile_id;

    my @data_levels;
    if ($self->coverage_in_gb) {
        @data_levels = split(/\t/,$self->coverage_in_gb);
    }
    elsif ($self->coverage_ratio) {
        @data_levels = split(/\t/,$self->coverage_ratio);
    }

    my @lsf_jobs;
    for my $model_bridge (Genome::ModelGroup->get($self->group_id)->model_bridges) {
        my $model = $model_bridge->model;
        my $subject_name = $model->subject_name;
        if($model->last_succeeded_build_directory) {
                my $build = $model->last_succeeded_build;
                my $last_build_dir = $model->last_succeeded_build_directory;
                my %metrics = map {$_->name => $_->value} $build->metrics; 
                my $data_available = $metrics{"instrument data total kb"} / 10**6;
                printf("%s\t%0.01f\n",$build->id, $data_available);
                my $model_id = $build->model_id;

                my $last_lsf_job;
                for my $level (@data_levels) {
                    my $out_file = "$outdir/$model_id.$level.out";
                    my $error_file = "$outdir/$model_id.$level.err";
                    if($level < $data_available || $self->coverage_ratio) {
                        #bsub command
                        if( ! -e "$error_file" ) {
                            my $lsf_dependency="";
                            if($last_lsf_job) {
                                $lsf_dependency = "-w 'ended($last_lsf_job)' "
                            }
                            my $cmd; 
                            my $user = Genome::Sys->username;
                            if ($self->coverage_in_gb) {
                                my $cmd = "bsub -N -u $user\@genome.wustl.edu $lsf_dependency-oo $out_file -eo $error_file -R 'select[mem>4000] rusage[mem=4000]'  genome model reference-alignment downsample $model_id --coverage-in-gb $level";
                            }
                            elsif ($self->coverage_ratio) {
                                my $cmd = "bsub -N -u $user\@genome.wustl.edu $lsf_dependency-oo $out_file -eo $error_file -R 'select[mem>4000] rusage[mem=4000]'  genome model reference-alignment downsample $model_id --coverage-in-ratio $level";
                            }
                            my ($line) = `$cmd`;
                            my ($lsf_jobid) = $line =~ /<(\d+)>/;
                            $last_lsf_job = $lsf_jobid;
                            push(@lsf_jobs,$lsf_jobid);
                        }
                    }
                }
        }
        UR::Context->commit() or die 'commit failed';
        UR::Context->clear_cache(dont_unload => ['Genome::ModelGroup', 'Genome::ModelGroupBridge']);
    }

    #dont progress until all above jobs have finished (done or not found)
    my $not_done = 1;
    foreach my $current_jobid (@lsf_jobs) {
        while ($not_done){
            sleep 60;
            my $job_info = `bjobs $current_jobid`;
            if ($job_info =~ m/DONE/i || $job_info =~ m/not found/) {
                $not_done = 0;
            }
        }
        $not_done = 1;
    }

    my @files = glob("$outdir/*.err");

    my %downsampled_to;# = ( 0.5 => [], 0.75 => [], 1 => [], 1.5 => [], 2 => [], 3 => [] );
#    my %group_for;# = ( 0.5 => 16722, 0.75 => 16723, 1 => 16710, 1.5 => 16711, 2 => 16712, 3 => 16733 );
    foreach my $level (sort @data_levels) {
        $downsampled_to{$level}++;
#        $group_for{$level} => $model_groups{$level}; #HAVE YET TO DEFINE MODEL GROUPS
    }

    for my $file (@files) {
        my ($model_id,$downsample_level) = $file =~ /^(\d+?)\.([0-9.]+?)\.err$/;
        print "$model_id\t$downsample_level Gbp\n";

        my $fh = Genome::Sys->open_file_for_reading($file);

        my ($instrument_data_line) = grep /Your new instrument-data id is/, ($fh->getlines);

        my ($instrument_data_id) = $instrument_data_line =~ /(\d+)$/;

        #genome model copy 123456789 "name=Copy of my Awesome Model" processing_profile="use this processing profile instead" auto_build_alignments=0
        my $model = Genome::Model->get($model_id);
        my $model_name = $model->name;
        my $obj;
        if ($self->coverage_in_gb) {
            $obj = Genome::Model::Command::Copy->execute( model => $model, overrides => [ "name='${model_name}.downsampled-to-$downsample_level-Gbp'", "processing_profile=$processing_profile_id", "auto_build_alignments=0", "instrument_data=$instrument_data_id"] );
        }
        elsif ($self->coverage_ratio) {
            $obj = Genome::Model::Command::Copy->execute( model => $model, overrides => [ "name='${model_name}.downsampled-to-$downsample_level-ratio'", "processing_profile=$processing_profile_id", "auto_build_alignments=0", "instrument_data=$instrument_data_id"] );
        }
        unless($obj) {
            die "Unable to copy $model_name with instrument data $instrument_data_id\n";
        }
        my $new_id = $obj->_new_model->id;
        unless($new_id) {
            die "Unable to grab new model id\n";
        }

        push @{$downsampled_to{$downsample_level}}, $new_id;
    }
    UR::Context->commit;

    #make model groups
    my %model_groups;
    my $model_group_name = Genome::ModelGroup->get($self->group_id)->name;
    foreach my $level (@data_levels) {
        my $new_model_group = Genome::ModelGroup->create(
            name => "$model_group_name.downsampled_to_$level",
        );
        unless($new_model_group) {
            $self->error_message("Unable to create modelgroup for downsampling level $level");
            return;
        }
        $new_model_group->assign_models(@{$downsampled_to{$level}});
    } 

    return 1;
}

sub byChrPos {
    my ($chr_a, $pos_a) = split(/\t/, $a);
    my ($chr_b, $pos_b) = split(/\t/, $b);

    $chr_a cmp $chr_b
        or
    $pos_a <=> $pos_b;
}

1;
