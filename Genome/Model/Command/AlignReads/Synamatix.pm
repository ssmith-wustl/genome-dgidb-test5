
package Genome::Model::Command::AlignReads::Synamatix;

use strict;
use warnings;

use UR;
use Command;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => ['source_directory','refseq_directory','destination_directory'],
);

sub help_brief {
    "launch the aligner for a given set of new reads"
}

sub help_detail {                       
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
    print "Running command 1 " 
        . "foo is " . (defined $self->foo ? $self->foo : '<not defined>')
         . ", " 
        . "bar is " . (defined $self->bar ? $self->bar : '<not defined>') 
        . "\n";     
    return 1;
}

1;

