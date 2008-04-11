
package Genome::Model::Command::Annotate::Sort;  

use strict;
use warnings;
use IO::File;

use above "Genome";                         

class Genome::Model::Command::Annotate::Sort {
    is => 'Command',                       
    has => [                                
        input	=> { type => 'String',      doc => "The input file" },
    ], 
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "#TODO fill in"             
}

sub help_synopsis { 
    return <<EOS
    #TODO fill me in
EOS
}

sub help_detail {  
    return <<EOS 
    #TODO fill out
EOS
}

sub execute {     
    my $self = shift;
	
	my $input_fh = IO::File->new($self->input);
    my $output_fh1 = IO::File->new(">".$self->input.".prioritize.1");
    my $output_fh2 = IO::File->new(">".$self->input.".prioritize.2");
	
    my @lines = $input_fh->getlines;
    my @lines_to_sort;
	shift @lines;

    while (my $line = shift @lines){
	    my @fields = split(',', $line);
        if ( $fields[7] == 0 and $fields[8] > 0 ){
            push @lines_to_sort, \@fields; 
        }
    }
    
    @lines_to_sort = sort { $b->[6] <=> $a->[6] } sort { $b->[8] cmp $a->[8] } @lines_to_sort;

    foreach (@lines_to_sort){
        if ($_->[6] >= 4 && $_->[8] >= 10 && !($_->[22] == 1 && $_->[8] == 0 && $_->[15] > 0) && !($_->[22] == 0 && $_->[8] == 0 && $_->[15] == 0) )
		{ 
			$output_fh1->print( join(",", @$_) ); 
        }else {
            $output_fh2->print( join(",", @$_) ); 
        }
    }
		
    return 0;
}

1;

