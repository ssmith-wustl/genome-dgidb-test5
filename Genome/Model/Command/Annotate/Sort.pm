
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
	
	my $input_fh = File::IO->new($self->input);
    my $output_fh1 = File::IO->new(">".$self->input.".prioritize.1");
    my $output_fh2 = File::IO->new(">".$self->input.".prioritize.2");
	    
    my @lines = $input_fh->getlines;
    my @lines_to_sort;
    while (my $line = shift @lines){
	    my @fields = split(',', $line);
        if ( $fields[8] == 0 and $fields[9] > 0 ){
            push @lines_to_sort, \@fields; 
        }
    }
    
    @lines_to_sort = sort { $b->[7] <=> $a->[7] } sort { $b->[9] cmp $a->[9] } @lines_to_sort;

    foreach (@lines_to_sort){
        if ($_->[7] >= 4 && $_->[9] >= 10 && !($_->[23] == 1 && $_->[9] == 0 && $_->[16] > 0) && !($_->[23] == 0 && $_->[9] == 0 && $_->[16] == 0) ) {
            $output_fh1->print( join(",", @$_) ); 
        }else {
            $output_fh2->print( join(",", @$_) ); 
        }
    }
		
    return 0;
}

1;

