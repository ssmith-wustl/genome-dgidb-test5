package Genome::DataSource::ExperimentalMetrics;

use Genome;

use strict;
use warnings;

class Genome::DataSource::ExperimentalMetrics {
    is => ['UR::DataSource'],
    type_name => 'genome datasource experimental metrics',
    doc => 'Used to switch between the different comma delimited files used to store the experimental metric data',
};

sub resolve_data_sources_for_rule {
    my($self,$rule) = @_;

    unless ($rule->isa('UR::BoolExpr')) {
        # was a rule template.  Probably in the process of doing a cross datasource join
        return $self;
    }

    my $model_id = $self->_get_value_from_rule('model_id', $rule);
    unless ($model_id) {
        $self->error_message("Can't resolve final data source: no model_id specified in rule with id ".$rule->id);
        return;
    }
    unless (Genome::Model->get(id => $model_id)) {
        $self->error_message("No model for model_id $model_id");
        return;
    }

    my $ref_seq_id = $self->_get_value_from_rule('chromosome', $rule);
    unless (defined $ref_seq_id) {
        $self->error_message("Can't resolve final data source: no chromosome specified in rule with id ".$rule->id);
        return;
    }

    my @subject_class_parts = split('::', $rule->subject_class_name);
    my $ds_class = sprintf('Genome::DataSource::Model%s::%s%s',
                            $model_id,
                            $subject_class_parts[-1],
                            $ref_seq_id);
    my $ds = UR::DataSource->get($ds_class);
    unless($ds) {
        my @e = sort { $a->date_completed <=> $b->date_completed }
             Genome::Model::Command::AddReads::PostprocessVariations::Maq->get(model_id => $model_id,
                                                                        ref_seq_id => $ref_seq_id);
        my $metric_file = $e[-1]->experimental_variation_metrics_file_basename();
        $metric_file .= '.csv';
        # Hack to fixup data that's in transisition 
        $metric_file =~ s/maq_snp_related_metrics/identified_variations/;
        $metric_file =~ s/snps_/snips_/;

        unless (-f $metric_file) {
            $self->error_message("Metric file $metric_file does not exist");
            return;
        }
        
        $self->_experimental_metric_data_source_factory(ds_class => $ds_class,
                                                        model_id => $model_id,
                                                        rule     => $rule,
                                                        source_file => $metric_file,
                                                       ); 

    }
    return $ds_class;
}


# Maybe this should be part of UR::BoolExpr?
sub _get_value_from_rule {
    my($self,$property,$rule) = @_;

    my $value = $rule->specified_value_for_property_name($property);
    unless ($value) {
        # No value specified directly, try decomposing the id
        my $rule_id = $rule->specified_value_for_property_name('id');
        my $class_meta = $rule->subject_class_name->get_class_object();
        my @id_property_names = $class_meta->id_property_names;
        my @id_property_values = $class_meta->get_composite_id_decomposer->($rule_id);

        for (my $i = 0; $i < @id_property_names; $i++) {
            if ($id_property_names[$i] eq $property) {
                $value = $id_property_values[$i];
                last;
            }
        }
    }
    return $value;
}

    

# Column and sort order for the created data sources
sub _column_order {
    return qw(chromosome position reference_base variant_base snp_quality total_reads avg_map_quality
              max_map_quality n_max_map_quality avg_sum_of_mismatches max_sum_of_mismatches
              n_max_sum_of_mismatches avg_base_quality max_base_quality n_max_base_quality
              avg_windowed_quality max_windowed_quality n_max_windowed_quality
              plus_strand_unique_by_start_site minus_strand_unique_by_start_site
              unique_by_sequence_content plus_strand_unique_by_start_site_pre27
              minus_strand_unique_by_start_site_pre27 unique_by_sequence_content_pre27 ref_total_reads
              ref_avg_map_quality ref_max_map_quality ref_n_max_map_quality ref_avg_sum_of_mismatches
              ref_max_sum_of_mismatches ref_n_max_sum_of_mismatches ref_avg_base_quality ref_max_base_quality
              ref_n_max_base_quality ref_avg_windowed_quality ref_max_windowed_quality ref_n_max_windowed_quality
              ref_plus_strand_unique_by_start_site ref_minus_strand_unique_by_start_site
              ref_unique_by_sequence_content ref_plis_strand_unique_by_start_site_pre27
              ref_minus_strand_unique_by_start_site_pre27 ref_unique_by_sequence_content_pre27);
            
}
sub _sort_order {
    return qw(chromosome position);
}

sub _experimental_metric_data_source_factory {
    my($self,%args) = @_;

    # Each "child" data source will be a database of only one file - any joining we may want to do
    # will happen in the Context 
    my $source_file = $args{'source_file'};
    Sub::Install::install_sub({
        into => $args{'ds_class'},
        as   => 'server',
        code => sub { $source_file },
    });

    my $delimiter = ', ';
    Sub::Install::install_sub({
        into => $args{'ds_class'},
        as   => 'delimiter',
        code => sub { $delimiter },
    });

    Sub::Install::install_sub({
        into => $args{'ds_class'},
        as   => 'column_order',
        code => \&_column_order,
    });

    Sub::Install::install_sub({
        into => $args{'ds_class'},
        as   => 'skip_first_line',
        code => sub { 1; },
    });

    Sub::Install::install_sub({
        into => $args{'ds_class'},
        as   => 'sort_order',
        code => \&_sort_order,
    });

    # The VariationPosition class is IDed by model_id (among others), but the files storing
    # the data don't have model_id values in them.  We need to move model_id from the property_names
    # list into the constant_property_names list.  Since each model will get its own data source class,
    # this should work ok.
    my $model_id = $args{'rule'}->specified_value_for_property_name('model_id');
    Sub::Install::install_sub({
        into => $args{'ds_class'},
        as   => '_generate_loading_templates_arrayref',
        code => sub { my $class = shift;
                      $DB::single=1;
                      #my $templates = $class->SUPER::_generate_loading_templates_arrayref(@_);
                      
                      my $subref = $class->super_can('_generate_loading_templates_arrayref');
                      my $templates = $subref->($class,@_);

                      $templates->[0]->{'constant_property_names'} = ['model_id'];
                      $templates->[0]->{'constant_property_values'} = [ $model_id ];
                      return $templates;
                    }
    });


    UR::Object::Type->define(
        class_name => $args{'ds_class'},
        is => 'UR::DataSource::SortedCsvFile',
    );

}


1;
