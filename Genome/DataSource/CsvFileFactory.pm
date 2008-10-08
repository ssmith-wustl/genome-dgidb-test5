package Genome::DataSource::CsvFileFactory;

use Genome;
use UR::DataSource::SortedCsvFile;

use strict;
use warnings;

class Genome::DataSource::CsvFileFactory {
    is => ['UR::DataSource'],
    type_name => 'genome datasource snps',
    doc => 'Used to construct real data sources for classes which get their data from sorted csv files',
};

my %RESOLVER = (
    'Genome::Model::VariationPosition' =>  {
        constant_values => [ 'model_id' ],                  # which properties will be constant across the data source
        required_in_rule => [ 'model_id', 'ref_seq_id' ],   # properties that must be in the rule
        parent_data_source_class => 'Genome::DataSource::VariationPositions',
        file_resolver => sub {                              # returns the name of the file.  args are from required_in_rule
                             my($model_id, $ref_seq_id) = @_;
                             #my @e = sort { $a->date_completed <=> $b->date_completed }
                             #    Genome::Model::Command::Build::ReferenceAlignment::FindVariations::Maq->get(model_id => $model_id,
                             #                                                               ref_seq_id => $ref_seq_id);
                             #my $snp_file = $e[-1]->snip_output_file();
                             # Hack to fixup data that's in transisition 
                             #$snp_file =~ s/maq_snp_related_metrics/identified_variations/;
                             #$snp_file =~ s/snps_/snips_/;

                             my $model = Genome::Model->get(id => $model_id);
                             return unless $model;

                             my $refseq = Genome::Model::RefSeq->get(model_id => $model_id, ref_seq_id => $ref_seq_id);
                             return unless $refseq;
                                
                             my($snp_file) = $model->_variant_list_files($refseq->ref_seq_name);

                             return $snp_file;
                          },
    },

    'Genome::Model::ExperimentalMetric' => {
        required_in_rule => [ 'model_id', 'ref_seq_id' ],
        constant_values => [ 'model_id' ],
        parent_data_source_class => 'Genome::DataSource::ExperimentalMetrics',
        file_resolver => sub {
                             my($model_id, $ref_seq_id) = @_;
                             #my @e = sort { $a->date_completed <=> $b->date_completed }
                             #    Genome::Model::Command::Build::ReferenceAlignment::PostprocessVariations::Maq->get(model_id => $model_id,
                             #                                                                      ref_seq_id => $chromosome);
                             #my $metric_file = $e[-1]->experimental_variation_metrics_file_basename();
                             #$metric_file .= '.csv';
                             ## Hack to fixup data that's in transisition
                             #$metric_file =~ s/maq_snp_related_metrics/identified_variations/;
                             #$metric_file =~ s/snps_/snips_/;

                             my $model = Genome::Model->get(id => $model_id);
                             return unless $model;

                             my $refseq = Genome::Model::RefSeq->get(model_id => $model_id, ref_seq_id => $ref_seq_id);
                             return unless $refseq;

                             my($metric_file) = $model->_variation_metrics_files($refseq->ref_seq_name);
                             return $metric_file;
                          },
    },
);

# Putting these things in here seems like a hack...
# If we get a bunch of these, move them out to perl modules of their own, 
# which is slightly less hacky, but still...
class Genome::DataSource::VariationPositions {
    is => 'UR::DataSource::SortedCsvFile',
};
sub Genome::DataSource::VariationPositions::delimiter { '\s+'; }
sub Genome::DataSource::VariationPositions::column_order { qw(ref_seq_name position reference_base consensus_base consensus_quality  
                                                               read_depth avg_num_hits max_mapping_quality min_conensus_quality) }
sub Genome::DataSource::VariationPositions::sort_order { qw(ref_seq_name position ) }
sub Genome::DataSource::VariationPositions::skip_first_line { 0; }

sub Genome::DataSource::VariationPositions::_generate_loading_templates_arrayref {
    my ($self,@args) = @_;

    my $subref = $self->super_can('_generate_loading_templates_arrayref');
    my $templates = $subref->(@_);

    $templates->[0]->{'constant_property_names'} = ['model_id'];
    return $templates;
}




class Genome::DataSource::ExperimentalMetrics {
    is => 'UR::DataSource::SortedCsvFile',
};
sub Genome::DataSource::ExperimentalMetrics::delimiter { ',\s*' }
sub Genome::DataSource::ExperimentalMetrics::column_order { qw(chromosome position reference_base variant_base snp_quality
                                       total_reads avg_map_quality max_map_quality n_max_map_quality avg_sum_of_mismatches
                                       max_sum_of_mismatches n_max_sum_of_mismatches avg_base_quality max_base_quality
                                       n_max_base_quality avg_windowed_quality max_windowed_quality n_max_windowed_quality
                                       plus_strand_unique_by_start_site minus_strand_unique_by_start_site
                                       unique_by_sequence_content plus_strand_unique_by_start_site_pre27
                                       minus_strand_unique_by_start_site_pre27 unique_by_sequence_content_pre27 ref_total_reads
                                       ref_avg_map_quality ref_max_map_quality ref_n_max_map_quality ref_avg_sum_of_mismatches
                                       ref_max_sum_of_mismatches ref_n_max_sum_of_mismatches ref_avg_base_quality ref_max_base_quality
                                       ref_n_max_base_quality ref_avg_windowed_quality ref_max_windowed_quality ref_n_max_windowed_quality
                                       ref_plus_strand_unique_by_start_site ref_minus_strand_unique_by_start_site
                                       ref_unique_by_sequence_content ref_plis_strand_unique_by_start_site_pre27
                                       ref_minus_strand_unique_by_start_site_pre27 ref_unique_by_sequence_content_pre27) }
sub Genome::DataSource::ExperimentalMetrics::sort_order { qw(chromosome position ) }
sub Genome::DataSource::ExperimentalMetrics::skip_first_line { 1; }
sub Genome::DataSource::ExperimentalMetrics::_generate_loading_templates_arrayref {
    my ($self,@args) = @_;

    my $subref = $self->super_can('_generate_loading_templates_arrayref');
    my $templates = $subref->(@_);
    $templates->[0]->{'constant_property_names'} = ['model_id'];
    return $templates;
}


    


sub create_iterator_closure_for_rule {
    my($self,$rule) = @_;

$DB::single=1;
    my $subject_class = $rule->subject_class_name;
    my $resolver_info = $RESOLVER{$subject_class};
    unless ($resolver_info) {
        die "Don't know how to create a data source for class $subject_class";
    }

    my @required_params = @{$resolver_info->{'required_in_rule'}};
    my @all_resolver_params;
    for (my $i = 0; $i < @required_params; $i++) {
        my $param_name = $required_params[$i];
        my @values = $self->resolve_value_from_rule($param_name,$rule);
        unless (@values) {
            die "Can't resolve data source: no $param_name specified in rule with id ".$rule->id;
        }

        $all_resolver_params[$i] = \@values;
    }
    # Hack! Pass the newly resolved info up to the caller
    $_[1] = $rule;

    my @resolver_param_combinations = $self->_get_combinations_of_resolver_params(@all_resolver_params);
    
    my @data_source_iterators;
    foreach my $resolver_params ( @resolver_param_combinations ) {
     
        my @subject_class_parts = split('::', $rule->subject_class_name);
        my @ds_name_parts = splice(@subject_class_parts, 2);  # get rid of 'Genome::Model'

        my $this_ds_rule_params = $rule->legacy_params_hash;
        for (my $i = 0; $i < @required_params; $i++) {
            push @ds_name_parts, $required_params[$i] . $resolver_params->[$i];
            $this_ds_rule_params->{$required_params[$i]} = $resolver_params->[$i];
        }
        my $ds_class = join('::', 'Genome::DataSource',
                             @ds_name_parts);
        my $ds = UR::DataSource->get($ds_class);
        unless ($ds) {
            $self->_create_sub_data_source($ds_class, $rule, $resolver_params);
        }

        my $this_ds_rule = UR::BoolExpr->resolve_for_class_and_params($rule->subject_class_name,%$this_ds_rule_params);
        push @data_source_iterators, $ds_class->create_iterator_closure_for_rule($this_ds_rule);
    }

    return $data_source_iterators[0] if (@data_source_iterators < 2);  # If we only made 1 (or 0), just return that one directly

    my $iterator = sub {
        while (@data_source_iterators) {
            while (my $thing = $data_source_iterators[0]->()) {
                return $thing;
            }
            shift @data_source_iterators;
        }

        return;
    };
    return $iterator;
}


sub _get_combinations_of_resolver_params {
    my($self,@resolver_params) = @_;

    return [] unless @resolver_params;

    my @sub_combinations = $self->_get_combinations_of_resolver_params(@resolver_params[1..$#resolver_params]);

    my @retval;
    foreach my $item ( @{$resolver_params[0]} ) {
        foreach my $sub_combinations ( @sub_combinations ) {
            push @retval, [ $item, @$sub_combinations ];
        }
    }

    return @retval;
}


# This one works when there is a property in the rule that gives you a hint
# about what it is you're looking for.  For example, the rule specifies model_id
# and you want ref_seq_id.  It will fetch all the ref_seq_ids for that model
sub alternate_resolve_value_from_rule {
    my($self,$needed_property_name,$rule) = @_;

    my $value = $rule->specified_value_for_property_name($needed_property_name);
    if ($value) {
        return $value;
    }

    # Not directly specified... try and figure out how to get there from here
    my $subject_class_name = $rule->subject_class_name;
    my $subject_class_meta = UR::Object::Type->get($subject_class_name);
    my $rule_template = $rule->get_rule_template;
    my @properties_in_rule = $rule_template->_property_names;  # Why is that method private?!
    
    my @alternate_values;

#    PROPERTY_IN_RULE:
#    foreach my $property_name ( @properties_in_rule ) {
        my $delegated_property = $subject_class_meta->get_property_meta_by_name($needed_property_name);
        my $alternate_needed_property;
        if ($delegated_property->via) {
            $alternate_needed_property = $delegated_property->to;
            $delegated_property = $subject_class_meta->get_property_meta_by_name($delegated_property->via);
        } else {
            die "Don't know how to get the remote property associated with property $needed_property_name on $subject_class_name ";
        }
        next unless ($delegated_property->is_delegated);

        my $reference = UR::Object::Reference->get(class_name => $subject_class_name, delegation_name => $delegated_property->property_name);

        # Didn't find it?  Maybe it's a reverse_id_by property - those are only stored in the forward direction...
        # FIXME - this code is a lot like the code in UR::Context::_get_template_data_for_loading
        my $reverse = 0;
        unless ($reference) {
            my @joins = $delegated_property->_get_joins;
            foreach my $join ( @joins ) {
                my @references = UR::Object::Reference->get(class_name   => $join->{'foreign_class'},
                                                            r_class_name => $join->{'source_class'});
                if (@references == 1) {
                    $reverse = 1;
                    $reference = $references[0];
                    last;
                } elsif (@references) {
                    Carp::confess(sprintf("Don't know what to do with more than one %d Reference objects between %s and %s",
                                           scalar(@references), $delegated_property->class_name, $join->{'foreign_class'}));
                }
            }
        }

        my %alternate_get_params;
        my $alternate_class = $reference->r_class_name();
        my @ref_properties = $reference->get_property_links();
        my $property_getter = $reverse ? 'r_property_name' : 'property_name';
        # collect properties from the rule that might apply to the alternate class

        foreach my $ref_property ( @ref_properties ) {
            my $ref_property_name = $ref_property->$property_getter;
            if (my $value = $rule->specified_value_for_property_name($ref_property_name)) {
                my $alternate_property_name = $ref_property->r_property_name;
                $alternate_get_params{$alternate_property_name} = $value;
            }
        }
#        next PROPERTY_IN_RULE unless $alternate_needed_property;  # Does this delegation get us to the right place?

        # get the needed property out of the loaded objects
        my @alternate_objects = $alternate_class->get(%alternate_get_params);
        @alternate_values = map { $_->$alternate_needed_property } @alternate_objects;
#        last PROPERTY_IN_RULE if (@alternate_values);
#    }

    if (@alternate_values) {
        if (scalar(@alternate_values) == 1) {
            $rule = $rule->add_filter($needed_property_name => $alternate_values[0]);
        } else {
            $rule = $rule->add_filter($needed_property_name => \@alternate_values);
        }
        $_[2] = $rule;
        return @alternate_values;
    }

    return;
}


# This works well when there's a direct connection between something in the rule, and the
# property you're looking for.  For example, model_name is in the rule and you want model_id
sub resolve_value_from_rule {
    my($self,$needed_property_name,$rule) = @_;

    my $value = $rule->specified_value_for_property_name($needed_property_name);
    if ($value) {
        return $value;
    }

    # Not directly specified... try and figure out how to get there from here
    my $subject_class_name = $rule->subject_class_name;
    my $subject_class_meta = UR::Object::Type->get($subject_class_name);
    my $rule_template = $rule->get_rule_template;
    my @properties_in_rule = $rule_template->_property_names;  # Why is that method private?!
    
    my @alternate_values;

    PROPERTY_IN_RULE:
    foreach my $property_name ( @properties_in_rule ) {
        my $delegated_property = $subject_class_meta->get_property_meta_by_name($property_name);
        next unless ($delegated_property->is_delegated);

        my $reference = UR::Object::Reference->get(class_name => $subject_class_name, delegation_name => $delegated_property->via);

        # Didn't find it?  Maybe it's a reverse_id_by property - those are only stored in the forward direction...
        # FIXME - this code is a lot like the code in UR::Context::_get_template_data_for_loading
        my $reverse = 0;
        unless ($reference) {
            my @joins = $delegated_property->_get_joins;
            foreach my $join ( @joins ) {
                my @references = UR::Object::Reference->get(class_name   => $join->{'foreign_class'},
                                                            r_class_name => $join->{'source_class'});
                if (@references == 1) {
                    $reverse = 1;
                    $reference = $references[0];
                    last;
                } elsif (@references) {
                    Carp::confess(sprintf("Don't know what to do with more than one %d Reference objects between %s and %s",
                                           scalar(@references), $delegated_property->class_name, $join->{'foreign_class'}));
                }
            }
        }

        my $value_from_rule = $rule->specified_value_for_property_name($property_name);

        my %alternate_get_params;
        my $alternate_class = $reference->r_class_name();
        my @ref_properties = $reference->get_property_links();
        my $property_getter = $reverse ? 'r_property_name' : 'property_name';
        # collect properties from the rule that might apply to the alternate class

        my $alternate_needed_property;
        foreach my $ref_property ( @ref_properties ) {
            my $ref_property_name = $ref_property->$property_getter;
            if ($ref_property_name eq $needed_property_name) {
                my $alt_getter = $reverse ? 'property_name' : 'r_property_name';
                $alternate_needed_property = $ref_property->$alt_getter();
            }
            my $alternate_property_name = $delegated_property->to;
            $alternate_get_params{$alternate_property_name} = $value_from_rule;
        }
        next PROPERTY_IN_RULE unless $alternate_needed_property;  # Does this delegation get us to the right place?

        # get the needed property out of the loaded objects
        my @alternate_objects = $alternate_class->get(%alternate_get_params);
        @alternate_values = map { $_->$alternate_needed_property } @alternate_objects;
        last PROPERTY_IN_RULE if (@alternate_values);
    }

    if (@alternate_values) {
        if (scalar(@alternate_values) == 1) {
            $rule = $rule->add_filter($needed_property_name => $alternate_values[0]);
        } else {
            $rule = $rule->add_filter($needed_property_name => \@alternate_values);
        }
        $_[2] = $rule;
        return @alternate_values;
    }

    # Try it another way
    return $self->alternate_resolve_value_from_rule($needed_property_name, $rule);

}

    



sub _create_sub_data_source {
    my($self,$ds_class, $rule, $resolver_params) = @_;

    my $resolver_info = $RESOLVER{$rule->subject_class_name};
    my $file_path = $resolver_info->{'file_resolver'}->(@$resolver_params);
    unless (defined $file_path) {
        die "Can't resolve data source: resolver for ".$rule->subject_class_name." returned nothing for params ".join(',',@$resolver_params);
    }
    unless (-e $file_path) {
        die "Can't resolve data source: resolver for ".$rule->subject_class_name." returned $file_path, but that path does not exist";
    }

    # FIXME - when this is a proper property of a data sources, move it there...
    Sub::Install::install_sub({
        into => $ds_class,
        as   => 'server',
        code => sub { $file_path },
    });

    my $parent = $resolver_info->{'parent_data_source_class'};
    UR::Object::Type->define(
        class_name => $ds_class,
        is => $parent,
    );

    return $ds_class;
}



sub _generate_template_data_for_loading {
    my($class,$rule_template) = @_;

    my $subject_class_name = $rule_template->subject_class_name;
    my $resolver_info = $RESOLVER{$subject_class_name};
    unless ($resolver_info) {
        Carp::confess("Don't know how to generate a loading template for $subject_class_name");
        #return $class->SUPER::_generate_template_data_for_loading($rule_template);
    }

    my $ds_class = $resolver_info->{'parent_data_source_class'};
    return $ds_class->_generate_template_data_for_loading($rule_template);
}


    

1;
