package Genome::Model::Event::Build::DeNovoAssembly;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use Regexp::Common;

class Genome::Model::Event::Build::DeNovoAssembly {
    is => 'Genome::Model::Event',
};

#METHODS FOR VERIFICATION
sub validate_params {
    my ($self, $step_name, $params, $assembler) = @_;

    my $stage = 'Genome::Model::Event::Build::DeNovoAssembly::'.$step_name.'::'.$assembler;
    my $valid_params = $stage->valid_params();

    #RETURNS EMPTY HASH REF IF NO VALID PARAMS

    foreach my $param (keys %$params) {
	unless (exists $valid_params->{$param}) {
	    $self->error_message("Invalid param name: $param for stage: $stage");
	    return;
	}
	my $value = $params->{$param};
	my $value_type = $valid_params->{$param}->{is};
	my $method = '_verify_type_is_'. lc $value_type;
	unless ($self->$method($value)) {
	    $self->message("Valid value for $param $value should be $value_type");
	    return;
	}
	if (exists $valid_params->{$param}->{valid_values}) {
	    unless (grep (/^$value$/, @{$valid_params->{$param}->{valid_values}})) {
		$self->error_message("Value for $param $value is not one of the valid values");
		return;
	    }
	}
    }
    
    return 1;
}

sub _verify_type_is_number {
    my ($self, $value) = @_;
    if ($value =~ /^$RE{num}{real}$/) {
	return 1;
    }
    return;
}

sub _verify_type_is_boolean {
    my ($self, $value) = @_;
    if ($value == 1) {
	return 1;
    }
    return;
}

sub _verify_type_is_string {
    my ($self, $value) = @_;
    #SUCCESSFUL IF ANYTHING IS PASSED
    return 1 if $value;
    return;
}

1;
