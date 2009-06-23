package Genome::Model::Tools::Velvet;

use strict;
use warnings;

use POSIX;
use Genome;
use Data::Dumper;
use Regexp::Common;

class Genome::Model::Tools::Velvet {
    is  => 'Command',
    is_abstract  => 1,
    has_optional => [
        version => {
            is   => 'String',
            doc  => 'velvet version, must be valid velvet version number like 0.7.22, 0.7.30. It takes installed as default.',
            default => 'installed',
        },
    ],
};

sub sub_command_sort_position { 14 }

sub help_brief {
    "Tools to run velvet, a short reads assembler, and work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt velvet ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}


sub resolve_version {
    my $self = shift;

    my ($type) = ref($self) =~ /\:\:(\w+)$/;
    $type = 'velvet'.lc(substr $type, 0, 1);

    my $ver = $self->version;
    $ver = 'velvet_'.$ver unless $ver eq 'installed';
    
    my @uname = POSIX::uname();
    $ver .= '-64' if $uname[4] eq 'x86_64';
    
    my $exec = "/gsc/pkg/bio/velvet/$ver/$type";
    unless (-x $exec) {
        $self->error_message("$exec is not excutable");
        return;
    }

    return $exec;
}

#DON'T NEED THIS ANYMORE
sub validate_params {
    my ($self, $params) = @_;
    
    my $valid_params = $self->valid_params();
    
    #print Dumper $valid_params;
    foreach my $param (keys %$params) {
	#VERIFY NAME
	unless (exists $valid_params->{$param}) {
	    $self->error_message("Invalid param name: $param");
	    return;
	}
	#VERIFY VALUE TYPE
	my $value = $params->{$param};
	my $value_type = $valid_params->{$param}->{is};
	my $method = '_verify_type_is_' . lc $value_type;
	unless ($self->$method($value)) {
	    $self->error_message("Value for $param should be $value_type and not $value");
	    return;
	}
	#VERIFY VALUE IS VALID
	if (exists $valid_params->{$param}->{valid_values}) {
	    unless (grep (/^$value$/, @{$valid_params->{$param}->{valid_values}})) {
		$self->error_message("$value is not one of valid values .. should be" . map {$_."\n"} @{$valid_params->{$param}->{valid_values}});
		return;
	    }
	}
    }
    return 1;
}

sub _verify_type_is_string {
    my ($self, $value) = @_;
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

sub valid_params {
    return {
	file_name => {
	    is => 'String',
	},
	directory => {
	    is => 'String',
	},
	hash_length => {
	    is => 'Number',
	    valid_values => [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31],
	},
	file_format => {
	    is => 'String',
	    valid_values => ['fasta', 'fastq', 'fasta.gz', 'fastq.gz', 'eland', 'gerald'],
	},
	read_type   => {
	    is => 'String',
	    valid_values => ['short', 'shortPaired', 'short2', 'shortPaired2', 'long', 'longPaired'],
	},
	cov_cutoff  => {
	    is => 'Number', 
	},
	read_trkg   => {
	    is => 'Boolean', 
	},
	amos_file   => {
	    is => 'Boolean', 
	},
	exp_cov     => {
	    is => 'Number', 
	},
	ins_length  => {
	    is => 'Integer', 
	},
	ins_length2 => {
	    is => 'Integer',
	},
	ins_length_long => {
	    is => 'Number', 
	},
	ins_length_sd => {
	    is => 'Number', 
	},
	ins_length2_sd => {
	    is => 'Number', 
	},
	ins_length_long_sd => {
	    is => 'Number', 
	},
	min_contig_lgth => {
	    is => 'Number', 
	},
	min_pair_count => {
	    is => 'Number',
	},
	max_branch_length => {
	    is => 'Number', 
	},
	max_indel_count => {
	    is => 'Number', 
	},
	max_coverage => {
	    is => 'Number',
	},
	max_divergence => {
	    is => 'Number', 
	},
	max_gap_count => {
	    is => 'Number', 
	},
	long_mult_cutoff => {
	    is => 'Number',
	},
	out_acefile => {
	    is => 'String', 
	},
	afg_file => {
	    is => 'String',
	},
	fastq_file => {
	    is => 'String',
	},
	time => {
	    is => 'String',
	},
	version => {
	    is => 'String',
	},
   };
}
   
1;

