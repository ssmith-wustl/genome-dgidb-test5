package Genome::DataSource::VariationPositions;

use Genome;
use UR::DataSource::SortedCsvFile;

use strict;
use warnings;

class Genome::DataSource::VariationPositions {
    is => ['UR::DataSource'],
    type_name => 'genome datasource snps',
    doc => 'Used to switch between the different tab delimited files used to store the variation data',
};

sub resolve_data_sources_for_rule {
    my($self,$rule) = @_;

    unless ($rule->isa('UR::BoolExpr')) {
        # was a rule template.  Probably in the process of doing a cross datasource join
        return $self;
    }

    my $model_id;
    unless ($model_id = $rule->specified_value_for_property_name('model_id')) {
        # No model_id specified directly, try decomposing the id
        my $rule_id = $rule->specified_value_for_property_name('id');
        my $class_meta = $rule->subject_class_name->get_class_object();
        my @id_property_names = $class_meta->id_property_names;
        my @id_property_values = $class_meta->get_composite_id_decomposer->($rule_id);

        for (my $i = 0; $i < @id_property_names; $i++) {
            if ($id_property_names[$i] eq 'model_id') {
                $model_id = $id_property_values[$i];
                last;
            }
        }
        unless ($model_id) {
            $self->error_message("Can't resolve final data source: no model_id specified in rule with id ".$rule->id);
            return;
        }
    }
    unless (Genome::Model->get(id => $model_id)) {
        $self->error_message("No model for model_id $model_id");
        return;
    }

    my $ref_seq_id = $rule->specified_value_for_property_name('ref_seq_id');
    unless (defined $ref_seq_id) {
        $self->error_message("Can't resolve final data source: no ref_seq_id specified in rule with id ".$rule->id);
        return;
    }

    my @subject_class_parts = split('::', $rule->subject_class_name);
    my $ds_class = sprintf('Genome::DataSource::Snps::Model%s::%s%s',
                            $model_id,
                            $subject_class_parts[-1],
                            $ref_seq_id);
    my $ds = UR::DataSource->get($ds_class);
    unless($ds) {
        my @e = sort { $a->date_completed <=> $b->date_completed }
             Genome::Model::Command::AddReads::FindVariations::Maq->get(model_id => $model_id,
                                                                        ref_seq_id => $ref_seq_id);
        my $snp_file = $e[-1]->snip_output_file();
        # Hack to fixup data that's in transisition 
        $snp_file =~ s/maq_snp_related_metrics/identified_variations/;
        $snp_file =~ s/snps_/snips_/;

        unless (-f $snp_file) {
            $self->error_message("Variation file $snp_file does not exist");
            return;
        }
        
        $self->_variation_data_source_factory(ds_class => $ds_class,
                                              model_id => $model_id,
                                              rule     => $rule,
                                              source_file => $snp_file,
                                             ); 

    }
    return $ds_class;
}

# Column and sort order for the created data sources
sub _column_order {
    return qw(ref_seq_id position reference_base consensus_base consensus_quality
              read_depth avg_num_hits max_mapping_quality min_conensus_quality);
}
sub _sort_order {
    return qw(ref_seq_id position);
}

sub _variation_data_source_factory {
    my($self,%args) = @_;


    my $model_id = $args{'rule'}->specified_value_for_property_name('model_id');

    # Each "child" data source will be a database of only one file - any joining we may want to do
    # will happen in the Context 
    my $source_file = $args{'source_file'};
    Sub::Install::install_sub({
        into => $args{'ds_class'},
        as   => 'server',
        code => sub { $source_file },
    });

    my $delimiter = '\s+';
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
        as   => 'sort_order',
        code => \&_sort_order,
    });

    # The VariationPosition class is IDed by model_id (among others), but the files storing
    # the data don't have model_id values in them.  We need to move model_id from the property_names
    # list into the constant_property_names list.  Since each model will get its own data source class,
    # this should work ok.
    Sub::Install::install_sub({
        into => $args{'ds_class'},
        as   => '_generate_loading_templates_arrayref',
        code => sub { my $class = shift;
                      # This should ever only return 1 template in the listref
                      # Note - since, at compile time, SUPER is UR::DataSource (this factory class' SUPER),
                      # the commented-out thing below would go to the wrong package.  
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
