
package Genome::Model::EqualColumnWidthTableizer;

use strict;
use warnings;

# Class Method ---------------------------------------------------------------

sub new{ return bless {}, shift }

sub convert_table_to_equal_column_widths_in_place{
    my ($self, $arrayref) = @_;
    
    my @max_length;
    for my $row (@$arrayref) {
        for my $col_num (0..$#$row) {
            $max_length[$col_num] ||= 0;
            if ($max_length[$col_num] < length($row->[$col_num])) {                
                $max_length[$col_num] = length($row->[$col_num]);
            }
        }
    }
    for my $row (@$arrayref) {
        for my $col_num (0..$#$row) {
            $row->[$col_num] .= ' ' x ($max_length[$col_num] - length($row->[$col_num]) + 1);
        }
    }  
}

1;