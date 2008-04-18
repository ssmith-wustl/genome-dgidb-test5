package Genome::Model::Command::Annotate::Prioritize;  

use strict;
use warnings;
use IO::File;

use above "Genome";                         

class Genome::Model::Command::Annotate::Prioritize 
{
    is => 'Command',                       
    has => 
    [                                
        file => { type => 'String', doc => "Report file", is_optional => 0, },
        # TODO parameterize out files?
    ], 
};

sub help_brief {
    return;
}

sub help_synopsis { 
    return <<EOS
EOS
}

sub help_detail {  
    return <<EOS 
EOS
}

sub execute 
{     
    my $self = shift;
	
    my $file = $self->file;

    `awk '{FS=",";if(\$8==0 && \$9>0 ) print}' $file | sort -t',' -nrk 7,7 -k 9,9|awk '{FS=",";if(\$7>=4 && \$9>=10 && !(\$23==1 && \$9==0 && \$16>0) && !(\$23==0 && \$9==0 && \$16==0)) {print  > "prioritize.1";} else {print  > "prioritize.2";} }'`;
    
    return 1;
    
    # FIXME unshell-ify!
    
    my $file = $self->file;
	my $input_fh = IO::File->new("< $file");
    $self->error_message("Can't open file ($file): $!")
        and return unless $input_fh;

    my $p1_file = $self->file . ".prioritize.1";
    my $output_fh1 = IO::File->new("> $p1_file");
    $self->error_message("Can't open file ($p1_file): $!")
        and return unless $output_fh1;

    my $p2_file = $self->file . ".prioritize.2";
    my $output_fh2 = IO::File->new("> $p2_file");
	$self->error_message("Can't open file ($p2_file): $!")
        and return unless $output_fh2;

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

