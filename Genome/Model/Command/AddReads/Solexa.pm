
# Rename the final word in the full class name <---
package Genome::Model::Command::AddReads::Solexa;

use strict;
use warnings;

use UR;
use Command;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => ['source_directory','destination_file'],                   # Specify the command's properties (parameters) <--- 
);

sub help_brief {
    "add reads to a genome model"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 


EOS
}

#sub create {                               # Rarely implemented.  Initialize things before execute <---
#    my $class = shift;
#    my %params = @_;
#    my $self = $class->SUPER::create(%params);
#    # ..do initialization here
#    return $self;
#}

#sub validate_params {                      # Pre-execute checking.  Not requiried <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}

sub execute {
    my $self = shift;
    print "Running command 1 ";
    return 1;
}

1;

