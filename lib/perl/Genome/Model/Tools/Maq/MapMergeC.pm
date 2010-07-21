package Genome::Model::Tools::Maq::MapMergeC;

use strict;
use warnings;

class Genome::Model::Tools::Maq::MapMergeC {
    is => 'Genome::Model::Tools::Maq',
    has => [
        output => { is => 'String', doc => 'pathname of the output map file', },
        inputs => { is => 'ArrayRef', doc => 'list of input map files ' },
    ],

};

sub help_brief {
    "Perl/C linkage for the maq mapmerge sub-command";
}

sub help_detail {
    return <<"EOS"
Provides a perl interface to maq's mapmerge sub-command
'output' is the pathname to the marged map file
'inputs' is a listref of pathnames of input map files
EOS
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    my $output = $self->output;
    my $inputs = $self->inputs;

    my $linkage_class = $self->c_linkage_class();
    my $function = $linkage_class . '::mapmerge';

    no strict 'refs';
    return $function->($output, @$inputs);
}

1;

