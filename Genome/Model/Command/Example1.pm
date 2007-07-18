
# Rename the final word in the full class name <---
package Genome::Model::Command::Example1;

use strict;
use warnings;

use UR;
use Command;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => ['foo','bar'],                   # Specify the command's properties (parameters) <--- 
);

sub help_brief {
    "example command 1"                     # Keep this to just a few words <---
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 

This is a dummy command.  Copy, paste and modify! 

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
    print "Running command 1 " 
        . "foo is " . $self->foo 
        . ", " 
        . "bar is " . $self->bar 
        . "\n";     
    return 1;
}

1;

