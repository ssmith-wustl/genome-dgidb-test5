package Genome::Model::Tools::AmpliconAssembly::Create;

use strict;
use warnings;

use Genome;

use File::Copy::Recursive;
use Regexp::Common;

class Genome::Model::Tools::AmpliconAssembly::Create {
    is => 'Command',
    has => [
    Genome::Model::Tools::AmpliconAssembly::Set->attributes,
    ],
};
#< Helps >#
sub help_brief {
    return 'Create an amplicon assembly';
}

sub help_detail {
    return <<EOS;
Create an amplicon assembly, it's directory structure and saves the properties.  This allows the other commands to be run smoothly by using the amplicon assembly's stored properties.
EOS
}

sub help_synopsis {
}

#< Command >#
sub sub_command_sort_position { 11; }

sub execute {
    my $self = shift;

    my %params = map { $_ => $self->$_ } grep { defined $self->$_ } Genome::Model::Tools::AmpliconAssembly::Set->attribute_names;
    my $amplicon_assembly = Genome::Model::Tools::AmpliconAssembly::Set->create(%params);
    unless ( $amplicon_assembly ) {
        $self->error_message("Can't create amplicon assembly.  See above errors.");
        return;
    }
    
    return 1;
}

1;

#$HeadURL$
#$Id$
