
package Genome::Model::Command::Annotate::Sort;  

use strict;
use warnings;

use above "Genome";                         

class Genome::Model::Command::Annotate::Sort {
    is => 'Command',                       
    has => [                                
        input	=> { type => 'String',      doc => "The input file" },
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
	
	my $input= $self->input;
	system("echo $input");
	
	system(qw{awk '{FS=",";if($8==0 && $9>0 ) print}' $input | sort -t',' -nrk 7,7 -k
		9,9|awk '{FS=",";if($7>=4 && $9>=10 && !($23==1 && $9==0 && $16>0) && !($23==0
		&& $9==0 && $16==0)) {print  > "prioritize.1";} else {print  >
		"prioritize.2";} }'});  
		
    return 0;
}

1;

