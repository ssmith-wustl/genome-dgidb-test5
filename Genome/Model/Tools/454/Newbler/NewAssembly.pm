package Genome::Model::Tools::454::Newbler::NewAssembly;

use strict;
use warnings;

use Data::Dumper;

class Genome::Model::Tools::454::Newbler::NewAssembly {
    is => 'Genome::Model::Tools::454::Newbler',
    has => [
            dir => {
		    is => 'String',
                    doc => 'pathname of the output directory',
                   },
	    assembler_version => {
		                  is => 'String',
				  doc => 'newbler assembler version',
				  is_optional => 1,
			         },
        ],

};

sub help_brief {
"genome-model tools newbler new-assembly --dir=DIR";
}

sub help_detail {
    return <<"EOS"

EOS
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;
    my $cmd = $self->full_bin_path('createProject') .' -t asm '. $self->dir;
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero return status from command '$cmd'");
        return
    }
    return 1;
}

1;

