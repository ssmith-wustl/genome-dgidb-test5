
package Genome::Model::Command::Annotate::FilterValidation;  

use strict;
use warnings;

use above "Genome";                         
use IO::File;

class Genome::Model::Command::Annotate::FilterValidation {
		is => 'Command',                       
		has => [                                
				input     			=> { type => 'String',      doc => "The infile, produced from sort" },
		        variant_validation  => { type => 'String',      doc => "The
				variant validation .csv file", default => '/gscuser/xshi/work/AML_SNP/VALIDATION/Ley_Siteman_AML_variant_validation.10mar2008a.csv' },
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

		my $input_fh = IO::File->new($self->input);
		my $variant_fh = IO::File->new($self->variant_validation);

#cat Ley_Siteman_AML_variant_validation.10mar2008a.csv | 
#awk '{FS="\t";

		my $matches;
		while (my $line = $variant_fh->getline) {
				my @columns = split('\t', $line);
				
				if($columns[41]eq"G"||$columns[41]eq"WT"||$columns[41]eq"S"||$columns[41]eq"LOH"||$columns[41]eq"O") {
						$matches .= $columns[1].",".$columns[3].",".$columns[4].",".$columns[5]."\n";	# > list
				}
		}

		system("grep -v -F '$matches' ".$self->input);

		return 0;
}

1;

