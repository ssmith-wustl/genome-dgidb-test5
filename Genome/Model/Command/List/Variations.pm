package Genome::Model::Command::List::Variations;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::Model::Command::List::Variations {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
             is_constant => 1, 
            value => 'Genome::Model::VariationPosition' 
        },
        show => { default_value => 'ref_seq_id,position,reference_base,consensus_base,consensus_quality,read_depth,avg_num_hits,max_mapping_quality,min_conensus_quality' },
    ],
};

class Genome::Model::Command::List::Variations::Iterator {
    is => 'UR::Object::Iterator',
#    has => [
#        sub_iterators => { is => 'ARRAY' },  # FIXME - this doesn't work :(
#    ],
    is_transactional => 0,
};

#sub execute {
#    my($class,%params) = @_;
#$DB::single=1;
#    my $self = $class->SUPER::create(%params);

    
sub _fetch {
    my $self = shift;
$DB::single=1;
    if (my $filter = $self->filter) {
        my($rule,%extra) =  UR::BoolExpr->create_from_filter_string($self->subject_class_name, $self->filter);
        my @ref_seq_list;

        unless ($rule->specifies_value_for_property_name('ref_seq_id')) {

            # The underlying Genome::Model::VariationPosition object don't support get()s without
            # specifying the ref_seq_id, since that would be a query across data sources.  Fake it
            # by making a command for each ref_seq_id.  
            # FIXME - maybe equivalent logic should be in either Genome::DataSource::CsvFileFactory or
            # Genome::Model::VariationPosition so stuff like a regular get() without ref_seq_id will
            # work, too

            my $model_id = $rule->specified_value_for_property_name('model_id');
            unless ($model_id) {
                $self->error_message('model_id is a required --filter parameter');
                return;
            }

            my $model = Genome::Model->get(id => $model_id);
            my @ref_seq_list = $model->get_subreference_names(reference_extension => 'bfa');  # Should work for all the models we have so far
            unless (@ref_seq_list) {
                $self->error_message("Found no reference sequences for model $model_id with extension 'bfa'");
                return;
            }

        } else {
            my $ref_seq_id = $rule->specified_value_for_property_name('ref_seq_id');
            if (ref($ref_seq_id) eq 'ARRAY') {
                @ref_seq_list = @$ref_seq_id;
            }
        }

        if (@ref_seq_list) {
            my @sub_iterators;
            foreach my $ref_seq_id ( @ref_seq_list ) {
                next if $ref_seq_id eq 'all_sequences';
                my $new_rule = $rule->add_filter(ref_seq_id => $ref_seq_id);
                my $sub_iterator = $self->subject_class_name->create_iterator( where => $new_rule );
                next unless $sub_iterator;
                push @sub_iterators, $sub_iterator;
            }

            my $iterator = Genome::Model::Command::List::Variations::Iterator->create(filter_rule_id => $rule->id);
            $iterator->{'sub_iterators'} = \@sub_iterators;
            return $iterator;
        }
    }
                
    return $self->SUPER::_fetch();
}


package Genome::Model::Command::List::Variations::Iterator;

sub next {
    my $self = shift;
    my $sub_iterators = $self->{'sub_iterators'}; # FIXME - sneaky 
  
$DB::single=1;
    while (@$sub_iterators) {
        while (my $object = $sub_iterators->[0]->next) {
            return $object;
        }
        shift @$sub_iterators;
    }

    return;
}



1;

