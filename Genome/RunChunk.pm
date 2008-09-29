package Genome::RunChunk;

use strict;
use warnings;

use Genome;
use File::Basename;

use GSC;

# This is so we can hook into the dw for run data.
use GSCApp;

# GSCApp removes our overrides to can/isa for Class::Autoloader.  Tell it to put them back.
App::Init->_restore_isa_can_hooks();

# This should not be necessary before working with objects which use App.
#App->init; 

class Genome::RunChunk {
    type_name => 'run chunk',
    table_name => 'GENOME_MODEL_RUN',
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
        genome_model_run_id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        sequencing_platform => { is => 'VARCHAR2', len => 255 },
        run_name            => { is => 'VARCHAR2', len => 500, is_optional => 1 },
        subset_name         => { is => 'VARCHAR2', len => 32, is_optional => 1, column_name => "LIMIT_REGIONS" },
        sample_name         => { is => 'VARCHAR2', len => 255 },
        #For now the subject_name is the sample_name
        #Not sure why via was not working so switched to calculated property
        subject_name        => {
                                calculate_from => ['sample_name'],
                                calculate => q|$sample_name|
                            },
        events              => { is => 'Genome::Model::Event', is_many => 1, reverse_id_by => "run" },
        seq_id              => { is => 'NUMBER', len => 15, is_optional => 1 },
        full_name           => { calculate_from => ['run_name','subset_name'], calculate => q|"$run_name/$subset_name"| },
        name                => {
                                doc => 'This is a long version of the name which is still used in some places.  Replace with full_name.',
                                is => 'String', 
                                calculate_from => ['run_name','sample_name'], 
                                calculate => q|$run_name. '.' . $sample_name| 
                            },

        # deprecated
        limit_regions       => { is => 'String', is_optional => 1, calculate_from => ['subset_name'], calculate=> q| $subset_name | },
        full_path           => { is => 'VARCHAR2', len => 767, is_optional => 1, column_name => "FULL_PATH" },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub get_or_create_from_read_set {
    my $class = shift;
    my $read_set = shift;

    #TODO:  This is now optional and once all read sets have a corresponding pse we can eliminate completely
    my $read_set_query_method_name = shift;

    my @pse_params = GSC::PSEParam->get(
                                        param_name => 'instrument_data_id',
                                        param_value => $read_set->id,
                                    );
    my $pse;
    if (scalar(@pse_params) == 1) {
        my $pse_param = $pse_params[0];
        my $ps = GSC::ProcessStep->get(process_to => 'queue instrument data for genome modeling');
        $pse = GSC::PSE->get(
                             ps_id => $ps->ps_id,
                             pse_id => $pse_param->pse_id,
                         );
    } elsif (scalar(@pse_params) > 1) {
        #ERROR or use one?
        $class->error_message('More than one pse found for pse param(instrument_data_id)');
        return;
    }

    my $run_chunk = Genome::RunChunk->get(seq_id => $read_set->id);

    my $run_name = $read_set->run_name;
    my $subset_name = $class->resolve_subset_name($read_set);
    my $full_path = $class->resolve_full_path($read_set);
    my $sequencing_platform = $class->resolve_sequencing_platform;
    if ($run_chunk) {
        if ($run_chunk->sequencing_platform ne $sequencing_platform) {
            die('Bad sequencing_platform value '. $sequencing_platform .'.  Expected '. $run_chunk->sequencing_platform);
        }
        if ($run_chunk->run_name ne $run_name) {
            $class->error_message("Bad run_name value $run_name.  Expected " . $run_chunk->run_name);
            return;
        }
        if ($run_chunk->full_path ne $full_path) {
            $class->warning_message("Run $run_name has changed location to $full_path from " . $run_chunk->full_path);
            $run_chunk->full_path($full_path);
        }
        if ($run_chunk->subset_name ne $subset_name) {
            $class->error_message("Bad subset_name $subset_name.  Expected " . $run_chunk->subset_name);
            return;
        }
    } else {
        my $query_value;
        if ($pse) {
            #TODO: Should be able to use pse subject_type instead of passing '$read_set_query_method_name'
            #Until PSEs exist for all data we will still use this crazy method name variable
            my ($subject_type) = $pse->added_param('subject_type');
            ($query_value) = $pse->added_param($read_set_query_method_name);
        } else {
            $query_value = $read_set->$read_set_query_method_name;
        }
        unless ($query_value) {
            die($read_set_query_method_name .'name not found for read set: '. $class->_desc_dw_obj($read_set));
        }
        $run_chunk  = $class->SUPER::create(
                                      genome_model_run_id => $read_set->id,
                                      seq_id => $read_set->id,
                                      run_name => $run_name,
                                      full_path => $full_path,
                                      subset_name => $subset_name,
                                      sequencing_platform => $sequencing_platform,
                                      #Currently there is no column for subject_name
                                      sample_name => $query_value,
                                  );
        unless ($run_chunk) {
            $class->error_message('Failed to get or create run record information for '. $class->_desc_dw_obj($read_set));
            return;
        }
    }
    return $run_chunk;
}

# WHY NOT USE RUN_NAME FROM THE DB????
sub old_name {
    my $self = shift;

    my $path = $self->full_path;

    my($name) = ($path =~ m/.*\/(.*EAS.*?)\/?$/);
    if (!$name) {
	   $name = "run_" . $self->id;
    }
    return $name;
}


sub _resolve_subclass_name {
	my $class = shift;

	if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) {
		my $sequencing_platform = $_[0]->sequencing_platform;
		return $class->_resolve_subclass_name_for_sequencing_platform($sequencing_platform);
	}
    elsif (my $sequencing_platform = $class->get_rule_for_params(@_)->specified_value_for_property_name('sequencing_platform')) {
        return $class->_resolve_subclass_name_for_sequencing_platform($sequencing_platform);
    }
	else {
		return;
	}
}


sub _resolve_subclass_name_for_sequencing_platform {
    my ($class,$sequencing_platform) = @_;
    my @type_parts = split(' ',$sequencing_platform);

    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);

    my $class_name = join('::', 'Genome::RunChunk' , $subclass);
    return $class_name;
}


sub _resolve_sequencing_platform_for_subclass_name {
    my ($class,$subclass_name) = @_;
    my ($ext) = ($subclass_name =~ /Genome::RunChunk::(.*)/);
    return unless ($ext);
    my @words = $ext =~ /[a-z]+|[A-Z](?:[A-Z]+|[a-z]*)(?=$|[A-Z])/g;
    my $sequencing_platform = lc(join(" ", @words));
    return $sequencing_platform;
}

1;
