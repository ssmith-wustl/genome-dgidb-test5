# review gsanders
# sub resolve_software_version has some valid todo's already but no idea if this will be used anytime soon

package Genome::Software;

use strict;
use warnings;

use Genome;

use File::stat;
use Time::localtime;

class Genome::Software {
    is_abstract => 1,
    has_optional => [
                     inputs_bx   => { is => 'UR::BoolExpr', id_by => 'inputs_id', is_optional => 1 },
                     inputs_id   => { is => 'Text', implied_by => 'inputs_bx', is_optional => 1 },
                     params_bx   => { is => 'UR::BoolExpr', id_by => 'params_id', is_optional => 1},
                     params_id   => { is => 'Text', implied_by => 'params_bx', is_optional => 1 },
                 ],
    attributes_have => [
                        is_input => { is => 'Boolean' },
                        is_param => { is => 'Boolean' },
                        ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    my $class_meta = $self->get_class_object;
    my %is_input;
    my $inherited_classes_array_ref = $class_meta->{_ordered_inherited_class_names};
    for my $class_name ($self->class,@{$inherited_classes_array_ref}) {
        if ($class_name eq __PACKAGE__) { last; }
        my $class_object = $class_name->get_class_object;
        my $has = $class_object->{has};
        for my $key (keys %{$has}) {
            my $attribute = $has->{$key};
            my $value = $self->$key;
            if ($attribute->{is_input} && !defined($is_input{$key})) {
                $is_input{$key} = $value;
            }
        }
    }
    if (keys %is_input) {
        my $bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($self->class,%is_input);
        $self->inputs_id($bx->id);
    }
    return $self;
}

sub inputs {
    my $self = shift;
    my $bx = $self->inputs_bx;
    return $bx->params_list;
}

sub params {
    my $self = shift;
    my $bx = $self->params_bx;
    return $bx->params_list;
}

sub resolve_software_version {
    #TODO, this tries to get svn revision info, then snapshot info, then date commited to trunk.  This actually isn't used anywhere to verify versions, so as long as it doesn't die here we are ok for the time being
    my $self = shift;
    my $base_dir = $self->base_dir;
    my $path = $base_dir .'.pm';
    unless (-f $path) {
        DIE('Failed to find expected perl module '. $path);
    }
    my $svn_info_hash_ref = $self->svn_info($path);
    if (defined $$svn_info_hash_ref{'Revision'}) {
        return $$svn_info_hash_ref{'Revision'};
    }
    if ($path =~ /\/gsc\/scripts\/opt\/genome-(\d+)\//) {
        return $1;
    }
    if ($path =~ /\/gsc\/scripts\/lib\/perl\//) {
        my $date = ctime(stat($path)->mtime);
        return 'app-'. $date;
    }
    #TODO: make condition for directory in svn tree that has not been added to svn

    #TODO: make condition for uncommited changes in svn tree, currently return zero
    #die('Failed to resolve_software_version for perl module path '. $path);
    return 0;
}

sub svn_info {
    my $self = shift;
    my $path = shift;
    my $info_string = `svn info $path`;
    chomp($info_string);
    my @lines = split("\n",$info_string);
    my %hash;
    for my $line (@lines) {
        $line =~ /([\w\s]*)\:\s*(.*)/;
        $hash{$1} = $2;
    }
    return \%hash;
}

sub get_input_value_by_name {
    my $self = shift;
    my $input_name = shift;
    my %inputs = $self->inputs;
    return $inputs{$input_name}
}

sub get_param_value_by_name {
    my $self = shift;
    my $param_name = shift;
    my %params = $self->params;
    return $params{$param_name};
}

package Genome::Software::AbstractBaseTest;

class Genome::Software::AbstractBaseTest {
    is => 'Genome::Software',
    has_input => [
    foo => { is => 'Text'},
    ],
};

1;
