package Genome::ProcessingProfile::ReferenceVariationSanger;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::ReferenceVariationSanger {
    is => 'Genome::ProcessingProfile',
    has_param => [
        command_name => {
            doc => 'build a profile to run gmt analysis auto-msa',
            valid_values => ['gmt analysis auto-msa'],
            default_value => 'gmt analysis auto-msa',
        },
	ace_fof => {
            type  =>  'String',
            doc  => "optional; provide an fof of ace files to run auto analysis including the full path",
 	    is_optional  => 1,
        },
	mail_me => {
	    type  =>  'Boolean',
            doc  => 'optional; default no mail; use mail-me option to get mailed when the analysis is complete',
    	    is_optional  => 1,
	},
	lsf_memory_requirement => {
            type  =>  'String',
            doc  => "optional provide gigs of resource to reserve for your lsf job as a number from 4 to 8; Default is 4",
	    is_optional  => 1,
  	    default => '4',
	},
	poly_source_1 => {
            type  =>  'String',
            doc  => 'optional; default is 1; poly-source-1 sets start of grouping of traces within a sample to be evaluated',
   	    is_optional  => 1,
	    default => '1',
        },
	poly_source_2 => {
            type  =>  'String',
            doc  => 'optional; default is 20; poly-source-2 sets stop of grouping of traces within a sample to be evaluated',
    	    is_optional  => 1,
 	    default => '20',
	},
	poly_indel_source_1 => {
            type  =>  'String',
            doc  => 'optional; default is 1; poly-indel-source-1 sets start of grouping of traces within a sample to be evaluated',
   	    is_optional  => 1,
 	    default => '1',
	},
	poly_indel_source_2 => {
            type  =>  'String',
            doc  => 'optional; default is 2; poly-indel-source-2 sets stop of grouping of traces within a sample to be evaluated',
    	    is_optional  => 1,
	    default => '2',
	},
	pretty_source_1 => {
            type  =>  'String',
            doc  => 'optional; default is 1; pretty-source-1 defines the start boundary of a sample name',
    	    is_optional  => 1,
 	    default => '1',
	},
	pretty_source_2 => {
            type  =>  'String',
            doc  => 'optional; default is 20; pretty-source-2 defines the end boundary of a sample name',
    	    is_optional  => 1,
 	    default => '20',
	},
    ],
    doc => "gmt analysis auto-msa -ace-fof ace.fof"
};

sub _initialize_model {
    my ($self,$model) = @_;
    warn "defining new model " . $model->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    return 1;
}

sub _initialize_build {
    my ($self,$build) = @_;
    warn "defining new build " . $build->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    return 1;
}

sub _execute_build {
    my ($self,$build) = @_;
    warn "executing build logic for " . $self->__display_name__ . ':' .  $build->__display_name__ . "\n";

    my $cmd = $self->command_name;
    my $args = $self->args;

    my $dir = $build->data_directory;

    my $exit_code = system "$cmd $args >$dir/output 2>$dir/errors";
    $exit_code /= 256;
    if ($exit_code != 0) {
        $self->error_message("Failed to run $cmd with args $args!  Exit code: $exit_code.");
        return;
    }

    return 1;
}

sub _validate_build {
    my $self = shift;
    my $dir = $self->data_directory;
    
    my @errors;
    unless (-e "$dir/output") {
        my $e = $self->error_message("No output file $dir/output found!");
        push @errors, $e;
    }
    unless (-e "$dir/errors") {
        my $e = $self->error_message("No output file $dir/errors found!");
        push @errors, $e;
    }

    if (@errors) {
        return;
    }
    else {
        return 1;
    }
}

1;

