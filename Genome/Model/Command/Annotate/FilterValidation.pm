
package Genome::Model::Command::Annotate::FilterValidation;  

use strict;
use warnings;

use above "Genome";                         

class Genome::Model::Command::Annotate::FilterValidation {
    is => 'Command',                       
    has => [                                
        foo     => { type => 'String',      doc => "some foozy thing" },
        bar     => { type => 'Boolean',     doc => "a flag to turn on and off", is_optional => 1 },
    ], 
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "WRITE A ONE-LINE DESCRIPTION HERE"                 
}

sub help_synopsis { 
    return <<EOS
genome-model example1 --foo=hello
genome-model example1 --foo=goodbye --bar
genome-model example1 --foo=hello barearg1 barearg2 barearg3
EOS
}

sub help_detail {  
    return <<EOS 
This is a dummy command.  Copy, paste and modify the module! 
CHANGE THIS BLOCK OF TEXT IN THE MODULE TO CHANGE THE HELP OUTPUT.
EOS
}

#sub create {                               # rarely implemented.  Initialize things before execute.  Delete unless you use it. <---
#    my $class = shift;
#    my %params = @_;
#    my $self = $class->SUPER::create(%params);
#    # ..do initialization here
#    return $self;
#}

#sub validate_params {                      # pre-execute checking.  Not requiried.  Delete unless you use it. <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}

sub execute {     
    my $self = shift;
	
	system(qw{cat Ley_Siteman_AML_variant_validation.10mar2008a.csv | awk
	'{FS="\t";if($42=="G"||$42=="WT"||$42=="S"||$42=="LOH"||$42=="O") print
	$2","$4","$5","$6;}' > list});
	
	system("grep -v -f list $1");
	
    return 0;
}

1;

