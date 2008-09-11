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
        file_sort_order => [ 'ref_seq_id', 'position' ],    # file is sorted by these columns
        file_column_order => [ qw(ref_seq_id position reference_base consensus_base consensus_quality  
                                  read_depth avg_num_hits max_mapping_quality min_conensus_quality) ],
        file_delimiter => '\s+',                            # delimiter between columns
        skip_first_line => 0,                               # does the first line have a header
        required_in_rule => [ 'model_id', 'ref_seq_id' ],   # properties that must be in the rule
        file_resolver => sub {                              # returns the name of the file.  args are from required_in_rule
                             my($model_id, $ref_seq_id) = @_;
                             my @e = sort { $a->date_completed <=> $b->date_completed }
                                 Genome::Model::Command::AddReads::FindVariations::Maq->get(model_id => $model_id,
                                                                                            ref_seq_id => $ref_seq_id);
                            my $snp_file = $e[-1]->snip_output_file();
                            # Hack to fixup data that's in transisition 
                            $snp_file =~ s/maq_snp_related_metrics/identified_variations/;
                            $snp_file =~ s/snps_/snips_/;
                            return $snp_file;
                          },
    },

    'Genome::Model::ExperimentalMetric' => {
        required_in_rule => [ 'model_id', 'chromosome' ],
        constant_values => [ 'model_id' ],
        file_sort_order => [ 'chromosome', 'position' ],
        file_column_order => [ qw(chromosome position reference_base variant_base snp_quality
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
              ref_minus_strand_unique_by_start_site_pre27 ref_unique_by_sequence_content_pre27) ],
        file_delimiter => ', ',
        skip_first_line => 1,
        file_resolver => sub {
                             my($model_id, $chromosome) = @_;
                             my @e = sort { $a->date_completed <=> $b->date_completed }
                                 Genome::Model::Command::AddReads::PostprocessVariations::Maq->get(model_id => $model_id,
                                                                                                   ref_seq_id => $chromosome);
                            my $metric_file = $e[-1]->experimental_variation_metrics_file_basename();
                            $metric_file .= '.csv';
                            # Hack to fixup data that's in transisition
                            $metric_file =~ s/maq_snp_related_metrics/identified_variations/;
                            $metric_file =~ s/snps_/snips_/;
                            return $metric_file;
                          },
    },
);

    

sub resolve_data_sources_for_rule {
    my($self,$rule) = @_;

    unless ($rule->isa('UR::BoolExpr')) {
        # was a rule template.  Probably in the process of doing a cross datasource join
        return $self;
    }

    my $subject_class = $rule->subject_class_name;
    my $resolver_info = $RESOLVER{$subject_class};
    unless ($resolver_info) {
        die "Don't know how to create a data source for class $subject_class";
    }

    my @required_params = @{$resolver_info->{'required_in_rule'}};
    my @resolver_params;
    for (my $i = 0; $i < @required_params; $i++) {
        my $param_name = $required_params[$i];
        my $value = $self->_get_value_from_rule($param_name, $rule);
        unless ($value) {
            die "Can't resolve data source: no $param_name specified in rule with id ".$rule->id;
        }

        $resolver_params[$i] = $value;
    }

    my @subject_class_parts = split('::', $rule->subject_class_name);
    my @ds_name_parts = splice(@subject_class_parts, 2);  # get rid of 'Genome::Model'
    for (my $i = 0; $i < @required_params; $i++) {
        push @ds_name_parts, $required_params[$i] . $resolver_params[$i];
    };
    my $ds_class = join('::', 'Genome::DataSource',
                             @ds_name_parts);
    my $ds = UR::DataSource->get($ds_class);
    return $ds_class if $ds;
 

    my $file_path = $resolver_info->{'file_resolver'}->(@resolver_params);
    unless (defined $file_path) {
        die "Can't resolve data source: resolver for $subject_class returned nothing for params ".join(',',@resolver_params);
    }
    unless (-e $file_path) {
        die "Can't resolve data source: resolver for $subject_class returned $file_path, but that path does not exist";
    }


    # FIXME - when these are proper properties of data sources, move them there...

    Sub::Install::install_sub({
        into => $ds_class,
        as   => 'server',
        code => sub { $file_path },
    });

    my $delimiter = $resolver_info->{'file_delimiter'};
    Sub::Install::install_sub({
        into => $ds_class,
        as   => 'delimiter',
        code => sub { $delimiter },
    });

    my @column_order = @{ $resolver_info->{'file_column_order'} };
    Sub::Install::install_sub({
        into => $ds_class,
        as   => 'column_order',
        code => sub { @column_order },
    });

    my @sort_order = @{ $resolver_info->{'file_sort_order'} };
    Sub::Install::install_sub({
        into => $ds_class,
        as   => 'sort_order',
        code => sub { @sort_order },
    });

    my $skip = $resolver_info->{'skip_first_line'};
    Sub::Install::install_sub({
        into => $ds_class,
        as   => 'skip_first_line',
        code => sub { $skip },
    });


    my @constant_property_names = @{ $resolver_info->{'constant_values'} };
    my @constant_property_values = map { $self->_get_value_from_rule($_, $rule) } @constant_property_names;
    Sub::Install::install_sub({
        into => $ds_class,
        as   => '_generate_loading_templates_arrayref',
        code => sub { my $class = shift;
                      # This should ever only return 1 template in the listref
                      # Note - since, at compile time, SUPER is UR::DataSource (this factory class' SUPER),
                      # the commented-out thing below would go to the wrong package.  
                      #my $templates = $class->SUPER::_generate_loading_templates_arrayref(@_);

                      my $subref = $class->super_can('_generate_loading_templates_arrayref');
                      my $templates = $subref->($class,@_);

                      $templates->[0]->{'constant_property_names'} = \@constant_property_names;
                      $templates->[0]->{'constant_property_values'} = \@constant_property_values;
                      return $templates;
                    }
    });


    UR::Object::Type->define(
        class_name => $ds_class,
        is => 'UR::DataSource::SortedCsvFile',
    );

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




1;
